//
//  MemoriesRepository.swift
//  Apollo
//
//  Protocol + mock for the Memories / Calendar screen data layer (PRD §11 §7–§8).
//

import Foundation

protocol MemoriesRepositoryProtocol: Sendable {
    /// Returns posts in the half-open interval [start, end) for the given user (UTC dates).
    func fetchCalendar(userID: UUID, start: Date, end: Date) async throws -> [MemoryDay]
    /// Returns the user's earliest post_date in UTC (nil when the user has no posts).
    func fetchFirstPostDate(userID: UUID) async throws -> Date?
}

enum MemoriesRepositoryError: Error, Sendable {
    case network
    case notFound
    case unknown
}

// MARK: - Mock

struct MockMemoriesRepository: MemoriesRepositoryProtocol {

    func fetchCalendar(userID: UUID, start: Date, end: Date) async throws -> [MemoryDay] {
        try await Task.sleep(for: .milliseconds(300))

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        // Seed some example post days in the range so previews are interesting.
        let allDates = stride(
            from: start.timeIntervalSince1970,
            to: end.timeIntervalSince1970,
            by: 86_400
        ).map { Date(timeIntervalSince1970: $0) }

        return allDates.enumerated().compactMap { idx, date in
            // Roughly every other day has a post.
            guard idx % 2 == 0 else { return nil }
            let comps = utcCal.dateComponents([.day], from: date)
            _ = comps.day
            return MemoryDay(
                id: UUID(),
                date: date,
                postID: UUID(),
                mainPhotoURL: nil,
                towerPhotoURLs: [],
                reactionCount: Int.random(in: 1...20),
                winCount: Int.random(in: 1...5),
                caption: "mock win"
            )
        }
    }

    func fetchFirstPostDate(userID: UUID) async throws -> Date? {
        try await Task.sleep(for: .milliseconds(100))
        // 90 days ago so pagination has something to page through.
        return Calendar.current.date(byAdding: .day, value: -90, to: Date())
    }
}
