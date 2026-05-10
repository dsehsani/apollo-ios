//
//  FeedRepository.swift
//  Apollo
//
//  Abstraction over the Feed data source. The Feed view model talks only to this
//  protocol; the concrete implementation can be swapped between MockFeedRepository
//  and SupabaseFeedRepository without touching the UI layer.
//

import Foundation

protocol FeedRepository: Sendable {
    var currentUserID: UUID { get }

    func fetchFeed(tab: FeedTab, cursor: FeedCursor?, limit: Int) async throws -> FeedPage
    func dailyQuote() async throws -> Quote
    func addReaction(postID: UUID, emoji: String) async throws
    func removeReaction(postID: UUID) async throws
    func fetchReactionsBreakdown(postID: UUID) async throws -> [Reaction]
    /// Batch-fetch emoji counts and current user's emoji for a set of post IDs.
    func fetchReactionSummaries(forPostIDs postIDs: [UUID]) async throws -> [PostReactionSummary]
    func reactionUpdatesStream() -> AsyncStream<ReactionUpdate>
    func deletePost(postID: UUID) async throws
    func reportPost(postID: UUID, reason: String) async throws
    func newPostsStream(tab: FeedTab) -> AsyncStream<Post>
}
