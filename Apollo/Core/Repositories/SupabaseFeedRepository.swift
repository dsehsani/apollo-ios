//
//  SupabaseFeedRepository.swift
//  Apollo
//
//  Supabase-backed FeedRepository. fetchFeed queries the `feed_posts` view which
//  joins posts → users → streaks and aggregates photo/reaction/comment counts.
//  All other methods remain stubs until their respective tables are wired up.
//

import Foundation
import Supabase

// MARK: - Decodable rows

private struct ReactionSummaryRow: Decodable {
    let post_id: UUID
    let emoji: String
    let user_id: UUID
}

/// Embedded `users(...)` on `reactions` rows (same shape as comments).
private struct ReactionBreakdownUserEmbed: Decodable {
    let username: String
    let avatar_url: String?
}

private struct ReactionBreakdownDBRow: Decodable {
    let id: UUID
    let post_id: UUID
    let user_id: UUID
    let emoji: String
    let created_at: String
    let users: ReactionBreakdownUserEmbed?

    enum CodingKeys: String, CodingKey {
        case id, post_id, user_id, emoji, created_at, users
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        post_id = try c.decode(UUID.self, forKey: .post_id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        emoji = try c.decode(String.self, forKey: .emoji)
        created_at = try c.decode(String.self, forKey: .created_at)
        if let embed = try? c.decode(ReactionBreakdownUserEmbed.self, forKey: .users) {
            users = embed
        } else if let arr = try? c.decode([ReactionBreakdownUserEmbed].self, forKey: .users), let first = arr.first {
            users = first
        } else {
            users = nil
        }
    }
}

private struct FeedPostRow: Decodable {
    let id: UUID
    let user_id: UUID
    let caption: String?
    let post_date: String   // Postgres `date` → "YYYY-MM-DD"
    let created_at: String  // Postgres `timestamptz` → may include microseconds / space separator
    let username: String
    let handle: String?
    let avatar_url: String?
    let photo_count: Int
    let wins_count: Int
    /// First photo URL (position 0) as a convenience scalar from the view.
    let photo_url: String?
    /// JSON array of all photo URLs ordered by position, e.g. ["https://…", "https://…"].
    /// Postgres returns this as a JSON column; decoded as [String] via a custom init.
    let photo_urls: [String]

    let reaction_count: Int
    let comment_count: Int
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case id, user_id, caption, post_date, created_at
        case username, handle, avatar_url
        case photo_count, wins_count, photo_url, photo_urls
        case reaction_count, comment_count, streak
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id            = try c.decode(UUID.self,    forKey: .id)
        user_id       = try c.decode(UUID.self,    forKey: .user_id)
        caption       = try c.decodeIfPresent(String.self, forKey: .caption)
        post_date     = try c.decode(String.self,  forKey: .post_date)
        created_at    = try c.decode(String.self,  forKey: .created_at)
        username      = try c.decode(String.self,  forKey: .username)
        handle        = try c.decodeIfPresent(String.self, forKey: .handle)
        avatar_url    = try c.decodeIfPresent(String.self, forKey: .avatar_url)
        photo_count   = try c.decode(Int.self,     forKey: .photo_count)
        wins_count    = try c.decode(Int.self,     forKey: .wins_count)
        photo_url     = try c.decodeIfPresent(String.self, forKey: .photo_url)
        reaction_count = try c.decode(Int.self,    forKey: .reaction_count)
        comment_count  = try c.decode(Int.self,    forKey: .comment_count)
        streak         = try c.decode(Int.self,    forKey: .streak)

        // photo_urls is a JSON column: Postgres returns it as a raw JSON string or nil.
        // Try decoding as [String] directly; fall back to a single-element array from photo_url.
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

final class SupabaseFeedRepository: FeedRepository, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // MARK: - fetchFeed

    func fetchFeed(tab: FeedTab, cursor: FeedCursor?, limit: Int) async throws -> FeedPage {
        do {
            // post_date is a Postgres `date` column stored in UTC. Compute today/yesterday
            // using the UTC calendar so the filter strings are plain YYYY-MM-DD date values.
            var utcCal = Calendar(identifier: .gregorian)
            utcCal.timeZone = TimeZone(identifier: "UTC")!
            var comps = utcCal.dateComponents([.year, .month, .day], from: Date())
            if tab == .yesterday {
                comps.day = (comps.day ?? 1) - 1
            }
            guard let dayStart = utcCal.date(from: comps),
                  let dayEnd = utcCal.date(byAdding: .day, value: 1, to: dayStart) else {
                throw FeedRepositoryError.unknown
            }

            // Plain date formatter for post_date (Postgres `date` type — no time component).
            let dateFmt = DateFormatter()
            dateFmt.dateFormat = "yyyy-MM-dd"
            dateFmt.timeZone = TimeZone(identifier: "UTC")!
            let startStr = dateFmt.string(from: dayStart)
            let endStr   = dateFmt.string(from: dayEnd)

            // ISO-8601 formatter for created_at (Postgres `timestamptz`) in cursor pagination.
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // Fetch accepted friend IDs so the feed is filtered to friends + self.
            // A fresh decoder is used here; the outer decoder is reused below.
            let friendsResp = try await supabase
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: currentUserID)
                .eq("status", value: "accepted")
                .execute()

            struct FriendIDRow: Decodable { let friend_id: UUID }
            let friendIDs = (try? JSONDecoder().decode([FriendIDRow].self, from: friendsResp.data))?
                .map(\.friend_id) ?? []
            let visibleIDs = friendIDs + [currentUserID]

            var query = supabase
                .from("feed_posts")
                .select()
                .in("user_id", values: visibleIDs)
                .gte("post_date", value: startStr)
                .lt("post_date", value: endStr)

            // Composite cursor: rows where (created_at < cursor.createdAt)
            // OR (created_at = cursor.createdAt AND id < cursor.id).
            if let cursor {
                let cursorDateStr = iso.string(from: cursor.createdAt)
                let cursorIDStr   = cursor.id.uuidString.lowercased()
                query = query.or(
                    "created_at.lt.\(cursorDateStr),and(created_at.eq.\(cursorDateStr),id.lt.\(cursorIDStr))"
                )
            }

            // Fetch limit+1 to detect whether more pages exist.
            let response = try await query
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(limit + 1)
                .execute()

            // Decode separately so a decode failure surfaces the offending payload type.
            // Date fields are kept as String in FeedPostRow to avoid ISO8601 format mismatches.
            let decoder = JSONDecoder()
            let rows = try decoder.decode([FeedPostRow].self, from: response.data)

            let hasMore = rows.count > limit
            let pageRows = Array(rows.prefix(limit))
            let posts = pageRows.map(mapRow)

            let nextCursor: FeedCursor?
            if hasMore, let last = pageRows.last,
               let lastDate = parseTimestamp(last.created_at) {
                nextCursor = FeedCursor(createdAt: lastDate, id: last.id)
            } else {
                nextCursor = nil
            }

            let ownPostExists = posts.contains { $0.user.id == currentUserID }

            return FeedPage(
                posts: posts,
                nextCursor: nextCursor,
                hasMore: hasMore,
                ownPostExists: ownPostExists
            )
        } catch let error as FeedRepositoryError {
            throw error
        } catch {
            throw FeedRepositoryError.network
        }
    }

    // MARK: - Row → Post mapper

    private func mapRow(_ r: FeedPostRow) -> Post {
        let mainURL = r.photo_url.flatMap(URL.init(string:))
        let createdAt = parseTimestamp(r.created_at) ?? Date()

        // Build ordered PhotoSlots from the full photo_urls array.
        // Slot 0 becomes mainPhotoURL; slots 1..n-1 become towerPhotos.
        let allURLs = r.photo_urls.compactMap(URL.init(string:))
        let firstURL = allURLs.first ?? mainURL
        let towerSlots: [PhotoSlot] = allURLs.dropFirst().enumerated().map { idx, url in
            PhotoSlot(id: UUID(), url: url, index: idx + 1)
        }

        return Post(
            id: r.id,
            user: PostUser(
                id: r.user_id,
                username: r.username,
                avatarURL: r.avatar_url.flatMap(URL.init(string:)),
                streak: r.streak
            ),
            createdAt: createdAt,
            caption: r.caption ?? "",
            photoCount: r.photo_count,
            mainPhotoURL: firstURL,
            towerPhotos: towerSlots,
            winsCount: r.wins_count,
            reactions: [],
            commentCount: r.comment_count,
            currentUserReaction: nil
        )
    }

    // MARK: - Timestamp parser
    // Postgres returns timestamptz in several formats depending on client settings:
    //   "2026-05-10 01:27:54.471287+00"   (space separator, microseconds, +00)
    //   "2026-05-10T01:27:54.471287+00:00" (T separator, microseconds, colon in offset)
    // The ISO8601DateFormatter handles T-separated forms; the DateFormatter fallback
    // handles the space-separated Postgres default.
    private func parseTimestamp(_ raw: String) -> Date? {
        let normalised = raw.replacingOccurrences(of: " ", with: "T")

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFull.date(from: normalised) { return d }

        let isoSec = ISO8601DateFormatter()
        isoSec.formatOptions = [.withInternetDateTime]
        if let d = isoSec.date(from: normalised) { return d }

        return nil
    }

    // GET /quotes — today's row
    func dailyQuote() async throws -> Quote {
        // TODO: select latest from `quotes` where date = today UTC, fall back to cycle.
        throw FeedRepositoryError.unknown
    }

    // POST /reactions — upsert so switching emoji in one round-trip
    func addReaction(postID: UUID, emoji: String) async throws {
        struct ReactionUpsert: Encodable {
            let post_id: UUID
            let user_id: UUID
            let emoji: String
        }

        let row = ReactionUpsert(post_id: postID, user_id: currentUserID, emoji: emoji)
        try await supabase
            .from("reactions")
            .upsert(row, onConflict: "post_id,user_id")
            .execute()
    }

    // DELETE /reactions — filtered by both post_id and user_id so users can only remove their own
    func removeReaction(postID: UUID) async throws {
        try await supabase
            .from("reactions")
            .delete()
            .eq("post_id", value: postID)
            .eq("user_id", value: currentUserID)
            .execute()
    }

    // GET /posts/:post_id/reactions — list reactors with profile fields for breakdown sheet.
    func fetchReactionsBreakdown(postID: UUID) async throws -> [Reaction] {
        do {
            let response = try await supabase
                .from("reactions")
                .select("""
                    id, post_id, user_id, emoji, created_at,
                    users(username, avatar_url)
                """)
                .eq("post_id", value: postID)
                .order("created_at", ascending: false)
                .limit(100)
                .execute()

            let decoder = JSONDecoder()
            let rows = try decoder.decode([ReactionBreakdownDBRow].self, from: response.data)
            return rows.map(mapReactionBreakdownRow)
        } catch let error as FeedRepositoryError {
            throw error
        } catch {
            throw FeedRepositoryError.network
        }
    }

    private func mapReactionBreakdownRow(_ r: ReactionBreakdownDBRow) -> Reaction {
        let author = r.users
        return Reaction(
            id: r.id,
            postID: r.post_id,
            userID: r.user_id,
            username: author?.username ?? "user",
            avatarURL: author?.avatar_url.flatMap(URL.init(string:)),
            emoji: r.emoji,
            createdAt: parseTimestamp(r.created_at) ?? Date()
        )
    }

    // Batch query: emoji counts + current user's emoji for a list of post IDs.
    func fetchReactionSummaries(forPostIDs postIDs: [UUID]) async throws -> [PostReactionSummary] {
        guard !postIDs.isEmpty else { return [] }

        let response = try await supabase
            .from("reactions")
            .select("post_id, emoji, user_id")
            .in("post_id", values: postIDs)
            .execute()

        let rows = try JSONDecoder().decode([ReactionSummaryRow].self, from: response.data)

        var countsByPost: [UUID: [String: Int]] = [:]
        var myEmojiByPost: [UUID: String] = [:]

        for row in rows {
            countsByPost[row.post_id, default: [:]][row.emoji, default: 0] += 1
            if row.user_id == currentUserID {
                myEmojiByPost[row.post_id] = row.emoji
            }
        }

        // Return a summary for every post that has at least one reaction.
        return postIDs.compactMap { id in
            guard let counts = countsByPost[id] else { return nil }
            return PostReactionSummary(
                postID: id,
                countsByEmoji: counts,
                currentUserEmoji: myEmojiByPost[id]
            )
        }
    }

    // Soft delete: posts.deleted_at = now()
    func deletePost(postID: UUID) async throws {
        // TODO: update `posts` set deleted_at = now() where id = postID and user_id = currentUserID.
        throw FeedRepositoryError.unknown
    }

    // POST /reports
    func reportPost(postID: UUID, reason: String) async throws {
        // TODO: insert into `reports` (post_id, reason, reporter_id).
        throw FeedRepositoryError.unknown
    }

    // Realtime subscription on `posts` filtered by user_id IN (friend_ids).
    func newPostsStream(tab: FeedTab) -> AsyncStream<Post> {
        // TODO: bridge Supabase Realtime channel into AsyncStream and emit decoded Post values.
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    // Realtime subscription on `reactions` table (INSERT/DELETE) filtered by friend post IDs.
    func reactionUpdatesStream() -> AsyncStream<ReactionUpdate> {
        // TODO: open a Supabase Realtime channel on `reactions`, decode INSERT → .added and
        // DELETE → .removed(reactionID:postID:), and yield into the stream.
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
