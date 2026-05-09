//
//  MockWinListRepository.swift
//  Apollo
//
//  In-memory mock for Win List development and previews.
//

import Foundation

final class MockWinListRepository: WinListRepository, @unchecked Sendable {

    // MARK: - Fixture data

    static let fixtureWins: [WinListItem] = [
        WinListItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Morning run",
            size: .m,
            repeatSchedule: .daily,
            currentStreak: 14,
            completedToday: false,
            sortOrder: 0
        ),
        WinListItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "Read 20 pages",
            size: .s,
            repeatSchedule: .daily,
            currentStreak: 7,
            completedToday: false,
            sortOrder: 1
        ),
        WinListItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "Deep work block",
            size: .l,
            repeatSchedule: .daily,
            currentStreak: 3,
            completedToday: false,
            sortOrder: 2
        ),
        WinListItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "Cold shower",
            size: .s,
            repeatSchedule: .daily,
            currentStreak: 0,
            completedToday: false,
            sortOrder: 3
        ),
        WinListItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "Meditate",
            size: .s,
            repeatSchedule: .daily,
            currentStreak: 21,
            completedToday: false,
            sortOrder: 4
        ),
    ]

    // MARK: - State

    enum ForceState {
        case loaded, empty, error
    }

    private let forceState: ForceState
    private var wins: [WinListItem]

    init(forceState: ForceState = .loaded) {
        self.forceState = forceState
        self.wins = forceState == .empty ? [] : MockWinListRepository.fixtureWins
    }

    // MARK: - WinListRepository

    func fetchWins(tab: WinTab) async throws -> [WinListItem] {
        try await simulateLatency()
        if forceState == .error { throw MockWinListError.network }

        switch tab {
        case .today:
            let incomplete = wins.filter { $0.isActive && !$0.completedToday }.sorted { $0.sortOrder < $1.sortOrder }
            let complete   = wins.filter { $0.isActive && $0.completedToday }.sorted { $0.sortOrder < $1.sortOrder }
            return incomplete + complete

        case .allWins:
            let active    = wins.filter { $0.isActive && !$0.completedToday }.sorted { $0.sortOrder < $1.sortOrder }
            let completed = wins.filter { $0.isActive && $0.completedToday }.sorted { $0.sortOrder < $1.sortOrder }
            let inactive  = wins.filter { !$0.isActive }.sorted { $0.sortOrder < $1.sortOrder }
            return active + completed + inactive
        }
    }

    func createWin(name: String, size: WinSize, repeatSchedule: WinRepeat, repeatDays: [Int]) async throws -> WinListItem {
        try await simulateLatency()
        if forceState == .error { throw MockWinListError.network }

        let win = WinListItem(
            name: name,
            size: size,
            repeatSchedule: repeatSchedule,
            currentStreak: 0,
            completedToday: false,
            sortOrder: wins.count,
            repeatDays: repeatDays
        )
        wins.append(win)
        return win
    }

    func toggleComplete(_ winID: UUID, date: Date) async throws -> WinListItem {
        try await simulateLatency()
        if forceState == .error { throw MockWinListError.network }

        guard let idx = wins.firstIndex(where: { $0.id == winID }) else {
            throw MockWinListError.notFound
        }
        wins[idx].completedToday.toggle()
        if wins[idx].completedToday {
            wins[idx].currentStreak += 1
        } else {
            wins[idx].currentStreak = max(0, wins[idx].currentStreak - 1)
        }
        return wins[idx]
    }

    func updateWin(_ win: WinListItem) async throws -> WinListItem {
        try await simulateLatency()
        if forceState == .error { throw MockWinListError.network }

        guard let idx = wins.firstIndex(where: { $0.id == win.id }) else {
            throw MockWinListError.notFound
        }
        wins[idx] = win
        return wins[idx]
    }

    func deleteWin(_ winID: UUID) async throws {
        try await simulateLatency()
        if forceState == .error { throw MockWinListError.network }
        wins.removeAll { $0.id == winID }
    }

    func reorderWins(_ orderedIDs: [UUID]) async throws {
        for (i, id) in orderedIDs.enumerated() {
            if let idx = wins.firstIndex(where: { $0.id == id }) {
                wins[idx].sortOrder = i
            }
        }
    }

    // MARK: - Private

    private func simulateLatency() async throws {
        try await Task.sleep(nanoseconds: 120_000_000)
    }
}

enum MockWinListError: Error {
    case network
    case notFound
}
