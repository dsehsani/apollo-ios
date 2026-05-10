//
//  MonthSectionView.swift
//  Apollo
//
//  One month block in the Memories calendar (PRD §11 §4B–§4D).
//  Renders the month header, weekday-column labels, and a 7-column day-tile grid.
//

import SwiftUI

struct MonthSectionView: View {
    let month: MemoryMonth
    let todayComponents: DateComponents  // pre-computed so every tile doesn't re-read the clock
    let onTileTap: (MemoryDay) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    // Pre-compute once per month using a UTC calendar.
    private var utcCal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    /// Number of days in this calendar month.
    private var daysInMonth: Int {
        var comps = DateComponents()
        comps.year  = month.year
        comps.month = month.month
        comps.day   = 1
        guard let firstDay = utcCal.date(from: comps) else { return 30 }
        return utcCal.range(of: .day, in: .month, for: firstDay)!.count
    }

    /// 0-based index of the first day's weekday (0 = Sunday).
    private var startWeekday: Int {
        var comps = DateComponents()
        comps.year  = month.year
        comps.month = month.month
        comps.day   = 1
        guard let firstDay = utcCal.date(from: comps) else { return 0 }
        // Calendar.weekday is 1-based (1 = Sunday).
        return (utcCal.component(.weekday, from: firstDay) - 1 + 7) % 7
    }

    private var monthName: String {
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.monthSymbols[month.month - 1]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            monthHeader

            weekdayRow
                .padding(.bottom, 4)

            LazyVGrid(columns: columns, spacing: 2) {
                // Filler blank tiles before the first day of the month.
                ForEach(0..<startWeekday, id: \.self) { _ in
                    BlankTileView()
                }

                // One tile per calendar day.
                ForEach(1...daysInMonth, id: \.self) { day in
                    let memDay = month.days[day]
                    let isToday = todayComponents.year == month.year
                        && todayComponents.month == month.month
                        && todayComponents.day == day

                    DayTileView(
                        dayNumber: day,
                        day: memDay,
                        isToday: isToday,
                        onTap: memDay.flatMap { d in d.hasPost ? { onTileTap(d) } : nil }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Header — "March 2026" (PRD §4B)

    private var monthHeader: some View {
        HStack(spacing: 0) {
            Text(monthName + " ")
                .font(.sfPro(28, weight: .regular))
                .foregroundStyle(Color.apolloPrimaryText)
            Text("\(month.year)")
                .font(.sfPro(28, weight: .bold))
                .foregroundStyle(Color.apolloPrimaryText)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Weekday row (PRD §4C)

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdayLabels.enumerated()), id: \.offset) { _, label in
                Text(label)
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTimeStreak)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    ScrollView {
        MonthSectionView(
            month: MemoryMonth(
                year: 2026,
                month: 5,
                days: [
                    3: MemoryDay(id: UUID(), date: Date(), postID: UUID(), mainPhotoURL: nil, towerPhotoURLs: [], reactionCount: 8, winCount: 2, caption: ""),
                    7: MemoryDay(id: UUID(), date: Date(), postID: UUID(), mainPhotoURL: nil, towerPhotoURLs: [], reactionCount: 4, winCount: 1, caption: ""),
                    10: MemoryDay(id: UUID(), date: Date(), postID: nil, mainPhotoURL: nil, towerPhotoURLs: [], reactionCount: 0, winCount: 0, caption: ""),
                ]
            ),
            todayComponents: {
                var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                c.timeZone = TimeZone(identifier: "UTC")
                return c
            }(),
            onTileTap: { _ in }
        )
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
