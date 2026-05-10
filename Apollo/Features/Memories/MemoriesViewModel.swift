//
//  MemoriesViewModel.swift
//  Apollo
//
//  @Observable view model for MemoriesView (PRD §11).
//
//  Pagination strategy:
//    • loadInitial  — loads the 3 most-recent calendar months plus the user's
//                     first-ever post date (used to know when to stop scrolling).
//    • loadOlderIfNeeded — called from the view when the user is within 1 month
//                          of the bottom of the rendered list; appends 3 more months.
//

import Foundation
import Observation

@Observable
final class MemoriesViewModel {

    enum Phase {
        case loading
        case loaded
        case error(String)
    }

    private(set) var phase: Phase = .loading
    /// Months ordered most-recent first.
    private(set) var months: [MemoryMonth] = []
    /// Earliest date the user ever posted, used to gate further pagination.
    private(set) var firstPostDate: Date?
    private(set) var isLoadingOlder: Bool = false

    // The oldest month boundary we have already loaded.
    private var oldestLoadedStart: Date?

    private let userID: UUID
    private let repository: any MemoriesRepositoryProtocol

    init(userID: UUID, repository: any MemoriesRepositoryProtocol) {
        self.userID = userID
        self.repository = repository
    }

    // MARK: - Public API

    func loadInitial() async {
        phase = .loading
        months = []
        oldestLoadedStart = nil

        do {
            // Fetch the user's earliest post date so we know when to stop scrolling.
            firstPostDate = try await repository.fetchFirstPostDate(userID: userID)

            let (chunkMonths, chunkStart) = buildMonthChunk(endingBefore: todayMonthStart(), count: 3)
            oldestLoadedStart = chunkStart

            // end = start of next month so the half-open range [chunkStart, nextMonth)
            // covers every day in the current month.
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let nextMonthStart = cal.date(byAdding: .month, value: 1, to: todayMonthStart())!

            let days = try await repository.fetchCalendar(
                userID: userID,
                start: chunkStart,
                end: nextMonthStart
            )

            months = buildMemoryMonths(from: chunkMonths, days: days)
            phase = .loaded
        } catch {
            phase = .error("Couldn't load your memories.")
        }
    }

    func refresh() async {
        await loadInitial()
    }

    /// Call this when the user scrolls to within 1 month of the oldest rendered month.
    /// - Parameter currentMonthIndex: 0-based index in `months` the user is viewing.
    func loadOlderIfNeeded(currentMonthIndex: Int) async {
        guard !isLoadingOlder,
              case .loaded = phase,
              currentMonthIndex >= months.count - 2 else { return }

        // Stop if we've already loaded back to (or before) the first post's month.
        if let first = firstPostDate, let oldest = oldestLoadedStart, oldest <= first {
            return
        }

        guard let oldest = oldestLoadedStart else { return }

        isLoadingOlder = true
        defer { isLoadingOlder = false }

        do {
            let (chunkMonths, chunkStart) = buildMonthChunk(endingBefore: oldest, count: 3)
            oldestLoadedStart = chunkStart

            let days = try await repository.fetchCalendar(
                userID: userID,
                start: chunkStart,
                end: oldest
            )

            let newMonths = buildMemoryMonths(from: chunkMonths, days: days)
            months.append(contentsOf: newMonths)

            Analytics.track(.calendarScrolled, [
                "months_scrolled": months.count
            ])
        } catch {
            // Silent — the months still render, just without photos.
        }
    }

    // MARK: - Private helpers

    /// Returns the UTC midnight date for the first day of the current month.
    private func todayMonthStart() -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        return cal.date(from: comps)!
    }

    /// Builds `count` consecutive month-start dates going backwards from `endingBefore`.
    /// Returns the list of month-start dates (most-recent first) and the oldest start.
    private func buildMonthChunk(endingBefore end: Date, count: Int) -> (monthStarts: [Date], oldestStart: Date) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var result: [Date] = []
        var cursor = cal.date(byAdding: .month, value: -1, to: end)!
        for _ in 0..<count {
            result.append(cursor)
            cursor = cal.date(byAdding: .month, value: -1, to: cursor)!
        }
        // result is ordered oldest→newest; reverse so most-recent first.
        return (result.reversed(), result.last!)
    }

    /// Groups `days` (from Supabase) into `MemoryMonth` structs aligned to the provided month-start dates.
    /// `monthStarts` must include the current month as first element and go back in time.
    private func buildMemoryMonths(from monthStarts: [Date], days: [MemoryDay]) -> [MemoryMonth] {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!

        // Index days by their UTC date string for O(1) lookup.
        var daysByDate: [String: MemoryDay] = [:]
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.timeZone = TimeZone(identifier: "UTC")!
        for day in days {
            let key = dateFmt.string(from: day.date)
            daysByDate[key] = day
        }

        // The first element of monthStarts is the most-recent month; build in that order.
        // When called for the initial chunk we include the current month by deriving it from todayMonthStart().
        let allMonthStarts: [Date]
        if let first = monthStarts.first {
            let currentMonthStart = todayMonthStart()
            if cal.compare(first, to: currentMonthStart, toGranularity: .month) == .orderedSame {
                allMonthStarts = monthStarts
            } else {
                // Prepend today's month when building the very first chunk.
                allMonthStarts = [currentMonthStart] + monthStarts
            }
        } else {
            allMonthStarts = []
        }

        return allMonthStarts.map { monthStart in
            let comps = cal.dateComponents([.year, .month], from: monthStart)
            let year  = comps.year!
            let month = comps.month!
            let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)!.count

            var daysMap: [Int: MemoryDay] = [:]
            for day in 1...daysInMonth {
                var dc = DateComponents()
                dc.year  = year
                dc.month = month
                dc.day   = day
                if let date = cal.date(from: dc) {
                    let key = dateFmt.string(from: date)
                    if let memDay = daysByDate[key] {
                        daysMap[day] = memDay
                    }
                }
            }

            return MemoryMonth(year: year, month: month, days: daysMap)
        }
    }
}
