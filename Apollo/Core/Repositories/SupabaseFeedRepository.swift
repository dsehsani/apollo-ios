//
//  SupabaseFeedRepository.swift
//  Apollo
//
//  Supabase-backed FeedRepository. All methods are stubs awaiting backend tables.
//  Endpoint shapes match PRD section 8.
//

import Foundation

final class SupabaseFeedRepository: FeedRepository, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // GET /feed
    // Request:  user_id, tab, cursor, limit
    // Response: posts, next_cursor, has_more
    func fetchFeed(tab: FeedTab, cursor: FeedCursor?, limit: Int) async throws -> FeedPage {
        // TODO: query `posts` filtered by friend_ids + tab window, joined with `users`,
        // `reactions` and `comments` counts. Apply cursor pagination on (created_at, id).
        throw FeedRepositoryError.unknown
    }

    // GET /quotes — today's row
    func dailyQuote() async throws -> Quote {
        // TODO: select latest from `quotes` where date = today UTC, fall back to cycle.
        throw FeedRepositoryError.unknown
    }

    // POST /reactions
    func addReaction(postID: UUID, emoji: ReactionEmoji) async throws {
        // TODO: upsert into `reactions` (post_id, user_id) with emoji.
        throw FeedRepositoryError.unknown
    }

    // DELETE /reactions/:reaction_id (resolved by post_id + current user)
    func removeReaction(postID: UUID) async throws {
        // TODO: delete from `reactions` where post_id = postID and user_id = currentUserID.
        throw FeedRepositoryError.unknown
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
}
