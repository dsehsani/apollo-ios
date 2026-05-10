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

// MARK: - Decodable row from the feed_posts view

private struct FeedPostRow: Decodable {
    let id: UUID
    let user_id: UUID
    let caption: String?
    let post_date: String   // Postgres `date` → "YYYY-MM-DD"
    let created_at: String  // Postgres `timestamptz` → may include microseconds / space separator
    let username: String
    let handle: String?
    let avatar_url: String?
    let photo_url: String?
    let reaction_count: Int
    let comment_count: Int
    let streak: Int
}

final class SupabaseFeedRepository: FeedRepository, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // MARK: - fetchFeed

    func fetchFeed(tab: FeedTab, cursor: FeedCursor?, limit: Int) async throws -> FeedPage {
        // #region agent log
        let dbLog: (String, [String: Any]) -> Void = { message, data in
            let ts = Date().timeIntervalSince1970
            var payload: [String: Any] = [
                "sessionId": "3d8d77", "runId": "run1",
                "location": "SupabaseFeedRepository.swift:fetchFeed",
                "message": message, "timestamp": Int64(ts * 1000)
            ]
            payload.merge(data) { _, new in new }
            if let json = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
               let line = String(data: json, encoding: .utf8) {
                print("[APOLLO_DEBUG] \(line)")
                let logPath = "/Volumes/Darius_SSD/Apollo/Apollo/.cursor/debug-3d8d77.log"
                let entry = line + "\n"
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile(); fh.write(entry.data(using: .utf8)!); try? fh.close()
                } else {
                    try? entry.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        // #endregion

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

            // ISO-8601 formatter kept for created_at (Postgres `timestamptz`) in cursor pagination.
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

            // #region agent log
            dbLog("entry", [
                "tab": tab.rawValue,
                "hasCursor": cursor != nil,
                "limit": limit,
                "currentUserID": currentUserID.uuidString,
                "startStr": startStr,
                "endStr": endStr
            ])
            // #endregion

            var query = supabase
                .from("feed_posts")
                .select()
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

            // #region agent log
            dbLog("before_execute", [:])
            // #endregion

            // Fetch limit+1 to detect whether more pages exist.
            // Split execute() from decode so we can log the raw body on failure.
            let response = try await query
                .order("created_at", ascending: false)
                .order("id", ascending: false)
                .limit(limit + 1)
                .execute()

            // #region agent log
            let bodySnippet = String(data: response.data.prefix(2048), encoding: .utf8) ?? "<binary>"
            dbLog("raw_response", ["statusCode": response.response.statusCode, "body": bodySnippet])
            // #endregion

            // Decode separately so a decode failure is caught and logged with the offending payload.
            // Date fields are kept as String in FeedPostRow to avoid ISO8601 format mismatches.
            let decoder = JSONDecoder()
            let rows: [FeedPostRow]
            do {
                rows = try decoder.decode([FeedPostRow].self, from: response.data)
            } catch {
                // #region agent log
                dbLog("decode_error", [
                    "errorType": String(describing: type(of: error)),
                    "description": error.localizedDescription,
                    "detail": String(describing: error)
                ])
                // #endregion
                throw error
            }

            // #region agent log
            dbLog("success", ["rowCount": rows.count])
            // #endregion

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
            // #region agent log
            dbLog("outer_catch", [
                "errorType": String(describing: type(of: error)),
                "description": error.localizedDescription,
                "detail": String(describing: error)
            ])
            // #endregion
            throw FeedRepositoryError.network
        }
    }

    // MARK: - Row → Post mapper

    private func mapRow(_ r: FeedPostRow) -> Post {
        let mainURL = r.photo_url.flatMap(URL.init(string:))
        let createdAt = parseTimestamp(r.created_at) ?? Date()
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
            photoCount: mainURL == nil ? 0 : 1,
            mainPhotoURL: mainURL,
            towerPhotos: [],
            winsCount: 0,
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
        // Normalise: replace leading space separator with T
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

        // #region agent log
        let dbLog: (String, [String: Any]) -> Void = { message, data in
            let ts = Date().timeIntervalSince1970
            var payload: [String: Any] = [
                "sessionId": "3d8d77", "runId": "run1",
                "location": "SupabaseFeedRepository.swift:addReaction",
                "message": message, "timestamp": Int64(ts * 1000)
            ]
            payload.merge(data) { _, new in new }
            if let json = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
               let line = String(data: json, encoding: .utf8) {
                print("[APOLLO_DEBUG] \(line)")
                let logPath = "/Volumes/Darius_SSD/Apollo/Apollo/.cursor/debug-3d8d77.log"
                let entry = line + "\n"
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile(); fh.write(entry.data(using: .utf8)!); try? fh.close()
                } else {
                    try? entry.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        dbLog("entry", ["postID": postID.uuidString, "userID": currentUserID.uuidString, "emoji": emoji])
        // #endregion

        let row = ReactionUpsert(post_id: postID, user_id: currentUserID, emoji: emoji)
        do {
            // #region agent log
            dbLog("before_execute", [:])
            // #endregion

            let response = try await supabase
                .from("reactions")
                .upsert(row, onConflict: "post_id,user_id")
                .execute()

            // #region agent log
            let body = String(data: response.data.prefix(2048), encoding: .utf8) ?? "<binary>"
            dbLog("raw_response", ["statusCode": response.response.statusCode, "body": body])
            // #endregion
        } catch {
            // #region agent log
            dbLog("reaction_error", [
                "errorType": String(describing: type(of: error)),
                "description": error.localizedDescription,
                "detail": String(describing: error)
            ])
            // #endregion
            throw error
        }
    }

    // DELETE /reactions — filtered by both post_id and user_id so users can only remove their own
    func removeReaction(postID: UUID) async throws {
        // #region agent log
        let dbLog: (String, [String: Any]) -> Void = { message, data in
            let ts = Date().timeIntervalSince1970
            var payload: [String: Any] = [
                "sessionId": "3d8d77", "runId": "run1",
                "location": "SupabaseFeedRepository.swift:removeReaction",
                "message": message, "timestamp": Int64(ts * 1000)
            ]
            payload.merge(data) { _, new in new }
            if let json = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
               let line = String(data: json, encoding: .utf8) {
                print("[APOLLO_DEBUG] \(line)")
                let logPath = "/Volumes/Darius_SSD/Apollo/Apollo/.cursor/debug-3d8d77.log"
                let entry = line + "\n"
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile(); fh.write(entry.data(using: .utf8)!); try? fh.close()
                } else {
                    try? entry.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        dbLog("entry", ["postID": postID.uuidString, "userID": currentUserID.uuidString])
        // #endregion

        do {
            // #region agent log
            dbLog("before_execute", [:])
            // #endregion

            let response = try await supabase
                .from("reactions")
                .delete()
                .eq("post_id", value: postID)
                .eq("user_id", value: currentUserID)
                .execute()

            // #region agent log
            let body = String(data: response.data.prefix(2048), encoding: .utf8) ?? "<binary>"
            dbLog("raw_response", ["statusCode": response.response.statusCode, "body": body])
            // #endregion
        } catch {
            // #region agent log
            dbLog("reaction_error", [
                "errorType": String(describing: type(of: error)),
                "description": error.localizedDescription,
                "detail": String(describing: error)
            ])
            // #endregion
            throw error
        }
    }

    // GET /posts/:post_id/reactions
    func fetchReactionsBreakdown(postID: UUID) async throws -> [Reaction] {
        // TODO: select reactions joined with users for post_id.
        throw FeedRepositoryError.unknown
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
