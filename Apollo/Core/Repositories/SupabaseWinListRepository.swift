//
//  SupabaseWinListRepository.swift
//  Apollo
//
//  Supabase-backed WinListRepository (PRD §04 §7–8).
//
//  Reads wins with today's completion status and current streak.
//  Toggle completion calls the `toggle_win_complete` RPC, which atomically
//  inserts/deletes the win_completions row and recomputes the streak.
//

import Foundation
import Supabase

final class SupabaseWinListRepository: WinListRepository, @unchecked Sendable {

    private let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // MARK: - Fetch

    func fetchWins(tab: WinTab) async throws -> [WinListItem] {
        // 1. Fetch wins for this user.
        let rows: [WinRow] = try await supabase
            .from("wins")
            .select()
            .eq("user_id", value: currentUserID)
            .is("deleted_at", value: (nil as Bool?))
            .order("sort_order", ascending: true)
            .execute()
            .value

        guard !rows.isEmpty else { return [] }

        // 2. Fetch today's completions (UTC date).
        let todayUTC = utcDateString(from: Date())
        let completionRows: [CompletionRow] = (try? await supabase
            .from("win_completions")
            .select("win_id")
            .eq("user_id", value: currentUserID)
            .eq("completed_date", value: todayUTC)
            .execute()
            .value) ?? []

        let completedIDs = Set(completionRows.map(\.win_id))

        // 3. Fetch streaks.
        let streakRows: [StreakRow] = (try? await supabase
            .from("streaks")
            .select("win_id, current_streak")
            .eq("user_id", value: currentUserID)
            .execute()
            .value) ?? []

        let streakMap: [UUID: Int] = Dictionary(
            uniqueKeysWithValues: streakRows.map { ($0.win_id, $0.current_streak) }
        )

        // 4. Map and filter.
        let items = rows.compactMap { row -> WinListItem? in
            guard let repeatSchedule = WinRepeat(rawValue: row.repeat) else { return nil }
            let size = WinSize(rawValue: row.size) ?? .m
            let completedToday = completedIDs.contains(row.id)

            return WinListItem(
                id: row.id,
                name: row.name,
                size: size,
                repeatSchedule: repeatSchedule,
                currentStreak: streakMap[row.id] ?? 0,
                completedToday: completedToday,
                sortOrder: row.sort_order,
                isActive: true,
                repeatDays: row.repeat_days ?? []
            )
        }

        switch tab {
        case .today:
            let today = todayWeekday()
            let relevant = items.filter { isScheduledToday($0, weekday: today) }
            let incomplete = relevant.filter { !$0.completedToday }
            let complete   = relevant.filter { $0.completedToday }
            return incomplete + complete

        case .allWins:
            let incomplete = items.filter { !$0.completedToday }
            let complete   = items.filter { $0.completedToday }
            return incomplete + complete
        }
    }

    // MARK: - Create

    func createWin(
        name: String,
        size: WinSize,
        repeatSchedule: WinRepeat,
        repeatDays: [Int]
    ) async throws -> WinListItem {
        let payload = WinInsert(
            user_id:     currentUserID.uuidString.lowercased(),
            name:        name,
            size:        size.rawValue,
            repeat:      repeatSchedule.rawValue,
            repeat_days: repeatDays.isEmpty ? nil : repeatDays,
            sort_order:  0
        )
        let row: WinRow = try await supabase
            .from("wins")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        return WinListItem(
            id: row.id,
            name: row.name,
            size: WinSize(rawValue: row.size) ?? .m,
            repeatSchedule: WinRepeat(rawValue: row.repeat) ?? .daily,
            currentStreak: 0,
            completedToday: false,
            sortOrder: row.sort_order,
            isActive: true,
            repeatDays: row.repeat_days ?? []
        )
    }

    // MARK: - Update

    func updateWin(_ win: WinListItem) async throws -> WinListItem {
        let payload = WinUpdate(
            name:        win.name,
            size:        win.size.rawValue,
            repeat:      win.repeatSchedule.rawValue,
            repeat_days: win.repeatDays.isEmpty ? nil : win.repeatDays
        )
        let row: WinRow = try await supabase
            .from("wins")
            .update(payload)
            .eq("id", value: win.id)
            .select()
            .single()
            .execute()
            .value

        return WinListItem(
            id: row.id,
            name: row.name,
            size: WinSize(rawValue: row.size) ?? .m,
            repeatSchedule: WinRepeat(rawValue: row.repeat) ?? .daily,
            currentStreak: win.currentStreak,
            completedToday: win.completedToday,
            sortOrder: row.sort_order,
            isActive: true,
            repeatDays: row.repeat_days ?? []
        )
    }

    // MARK: - Toggle complete

    func toggleComplete(_ winID: UUID, date: Date) async throws -> WinListItem {
        let dateStr = utcDateString(from: date)

        let result: ToggleResult = try await supabase
            .rpc("toggle_win_complete", params: ToggleParams(
                p_win_id: winID.uuidString.lowercased(),
                p_date: dateStr
            ))
            .execute()
            .value

        // Fetch the updated win row to return a full WinListItem.
        let row: WinRow = try await supabase
            .from("wins")
            .select()
            .eq("id", value: winID)
            .single()
            .execute()
            .value

        return WinListItem(
            id: row.id,
            name: row.name,
            size: WinSize(rawValue: row.size) ?? .m,
            repeatSchedule: WinRepeat(rawValue: row.repeat) ?? .daily,
            currentStreak: result.current_streak,
            completedToday: result.completed,
            sortOrder: row.sort_order,
            isActive: true,
            repeatDays: row.repeat_days ?? []
        )
    }

    // MARK: - Delete

    func deleteWin(_ winID: UUID) async throws {
        try await supabase
            .from("wins")
            .update(["deleted_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: winID)
            .execute()
    }

    // MARK: - Reorder

    func reorderWins(_ orderedIDs: [UUID]) async throws {
        // Batch update sort_order for each win.
        for (index, winID) in orderedIDs.enumerated() {
            try? await supabase
                .from("wins")
                .update(["sort_order": index])
                .eq("id", value: winID)
                .execute()
        }
    }

    // MARK: - Private helpers

    private func utcDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.string(from: date)
    }

    private func todayWeekday() -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 1 = Sunday, 2 = Monday, ... 7 = Saturday
        // Align to 0-indexed weekday where 0 = Sunday for PRD "custom days" usage.
        return cal.component(.weekday, from: Date()) - 1
    }

    private func isScheduledToday(_ item: WinListItem, weekday: Int) -> Bool {
        switch item.repeatSchedule {
        case .daily:
            return true
        case .weekly:
            return item.repeatDays.contains(weekday)
        case .custom:
            return item.repeatDays.contains(weekday)
        case .once:
            return !item.completedToday
        }
    }

    // MARK: - Row types

    private struct WinRow: Decodable {
        let id: UUID
        let name: String
        let size: String
        let `repeat`: String
        let repeat_days: [Int]?
        let sort_order: Int
    }

    private struct CompletionRow: Decodable {
        let win_id: UUID
    }

    private struct StreakRow: Decodable {
        let win_id: UUID
        let current_streak: Int
    }

    private struct WinInsert: Encodable {
        let user_id: String
        let name: String
        let size: String
        let `repeat`: String
        let repeat_days: [Int]?
        let sort_order: Int
    }

    private struct WinUpdate: Encodable {
        let name: String
        let size: String
        let `repeat`: String
        let repeat_days: [Int]?
    }

    private struct ToggleParams: Encodable {
        let p_win_id: String
        let p_date: String
    }

    private struct ToggleResult: Decodable {
        let completed: Bool
        let current_streak: Int
    }
}
