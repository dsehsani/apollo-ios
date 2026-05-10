//
//  SupabaseMemoriesRepository.swift
//  Apollo
//
//  Supabase-backed MemoriesRepository. Queries the existing `feed_posts` view
//  for date-range calendar data, and the `posts` table for the earliest post date
//  used to control infinite-scroll pagination.
//
//  Table / view dependencies (all pre-existing):
//    feed_posts  — user_id, post_date (date), photo_urls (json []), reaction_count, wins_count
//    posts       — user_id, post_date, deleted_at
//

import Foundation
import Supabase

// MARK: - Decodable row types

private struct CalendarPostRow: Decodable {
    let id: UUID
    let user_id: UUID
    let post_date: String       // "YYYY-MM-DD"
    let caption: String?
    let wins_count: Int
    let reaction_count: Int
    let photo_url: String?
    let photo_urls: [String]

    enum CodingKeys: String, CodingKey {
        case id, user_id, post_date, caption, wins_count, reaction_count, photo_url, photo_urls
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,   forKey: .id)
        user_id        = try c.decode(UUID.self,   forKey: .user_id)
        post_date      = try c.decode(String.self, forKey: .post_date)
        caption        = try c.decodeIfPresent(String.self, forKey: .caption)
        wins_count     = try c.decode(Int.self,    forKey: .wins_count)
        reaction_count = try c.decode(Int.self,    forKey: .reaction_count)
        photo_url      = try c.decodeIfPresent(String.self, forKey: .photo_url)

        // photo_urls is a JSON column — try [String], then raw JSON string, then fallback.
        if let arr = try? c.decode([String].self, forKey: .photo_urls) {
            photo_urls = arr
        } else if let raw = try? c.decode(String.self, forKey: .photo_urls),
                  let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([String].self, from: data) {
            photo_urls = decoded
        } else if let first = photo_url {
            photo_urls = [first]
        } else {
            photo_urls = []
        }
    }
}

private struct FirstPostDateRow: Decodable {
    let post_date: String
}

// MARK: - Repository

final class SupabaseMemoriesRepository: MemoriesRepositoryProtocol, @unchecked Sendable {

    let userID: UUID

    init(userID: UUID) {
        self.userID = userID
    }

    // MARK: - fetchCalendar

    func fetchCalendar(userID: UUID, start: Date, end: Date) async throws -> [MemoryDay] {
        let startStr = utcDateString(from: start)
        let endStr   = utcDateString(from: end)

        let rows: [CalendarPostRow] = try await supabase
            .from("feed_posts")
            .select("id, user_id, post_date, caption, wins_count, reaction_count, photo_url, photo_urls")
            .eq("user_id", value: userID)
            .gte("post_date", value: startStr)
            .lt("post_date", value: endStr)
            .order("post_date", ascending: true)
            .execute()
            .value

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        return rows.compactMap { row in
            guard let date = parseDate(row.post_date) else { return nil }

            let allURLs  = row.photo_urls.compactMap(URL.init(string:))
            let mainURL  = allURLs.first ?? row.photo_url.flatMap(URL.init(string:))
            let towerURLs = allURLs.count > 1 ? Array(allURLs.dropFirst()) : []

            return MemoryDay(
                id: row.id,
                date: date,
                postID: row.id,
                mainPhotoURL: mainURL,
                towerPhotoURLs: towerURLs,
                reactionCount: row.reaction_count,
                winCount: row.wins_count,
                caption: row.caption ?? ""
            )
        }
    }

    // MARK: - fetchFirstPostDate

    func fetchFirstPostDate(userID: UUID) async throws -> Date? {
        let rows: [FirstPostDateRow] = try await supabase
            .from("posts")
            .select("post_date")
            .eq("user_id", value: userID)
            .is("deleted_at", value: Bool?.none)
            .order("post_date", ascending: true)
            .limit(1)
            .execute()
            .value

        guard let first = rows.first else { return nil }
        return parseDate(first.post_date)
    }

    // MARK: - Private helpers

    private func utcDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.string(from: date)
    }

    /// Parses a "YYYY-MM-DD" string into a UTC midnight Date.
    private func parseDate(_ raw: String) -> Date? {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.date(from: raw)
    }
}
