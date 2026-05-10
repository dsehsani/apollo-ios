//
//  FeedViewModel.swift
//  Apollo
//
//  One @Observable view model per screen (per Apollo conventions). Owns Feed state,
//  optimistic reactions, pagination, refresh, and realtime new-post buffering.
//

import Foundation
import Observation

@Observable
@MainActor
final class FeedViewModel {

    enum Phase: Equatable {
        case loading
        case loaded
        case empty
        case partial
        case yesterdayEmpty
        case error
    }

    private static let pageSize = 20
    private static let prefetchTrigger = 3

    let repository: FeedRepository
    let commentsRepository: CommentsRepository

    var tab: FeedTab = .now
    var phase: Phase = .loading
    var posts: [Post] = []
    var pendingNewPosts: [Post] = []
    var quote: Quote?
    var hasMore: Bool = false
    private var nextCursor: FeedCursor?
    var isLoadingMore: Bool = false
    var isRefreshing: Bool = false
    var expandedCaptions: Set<UUID> = []
    var featuredPhotoIndex: [UUID: Int] = [:]
    var activeReactionPicker: UUID?
    /// Set when the user taps '+' in the reaction picker; triggers the custom-emoji sheet.
    var customEmojiTarget: UUID?
    var transientErrorMessage: String?

    private var newPostsTask: Task<Void, Never>?
    private var reactionUpdatesTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    var currentUserID: UUID { repository.currentUserID }
    var pendingNewPostsCount: Int { pendingNewPosts.count }

    init(repository: FeedRepository, commentsRepository: CommentsRepository) {
        self.repository         = repository
        self.commentsRepository = commentsRepository
    }

    // MARK: - Lifecycle

    func onAppear() {
        if posts.isEmpty && phase != .error {
            Task { await load(initial: true) }
        }
        subscribeRealtime()
    }

    func onDisappear() {
        newPostsTask?.cancel()
        newPostsTask = nil
        reactionUpdatesTask?.cancel()
        reactionUpdatesTask = nil
    }

    // MARK: - Loading

    func load(initial: Bool) async {
        if initial {
            phase = .loading
            posts = []
            nextCursor = nil
            hasMore = false
            pendingNewPosts = []
        }

        do {
            async let pageTask = repository.fetchFeed(tab: tab, cursor: nil, limit: Self.pageSize)
            async let quoteTask = repository.dailyQuote()
            let page = try await pageTask
            let q = try? await quoteTask

            posts = page.posts
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            quote = q
            phase = derivePhase(from: page)

            await mergeReactionSummaries(for: page.posts.map(\.id))
        } catch {
            phase = .error
            transientErrorMessage = "Couldn't load your feed."
        }
    }

    func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await load(initial: true)
    }

    func switchTab(_ next: FeedTab) {
        guard next != tab else { return }
        tab = next
        loadTask?.cancel()
        newPostsTask?.cancel()
        loadTask = Task { [weak self] in
            await self?.load(initial: true)
            self?.subscribeRealtime()
        }
    }

    func loadMoreIfNeeded(currentPost post: Post) {
        guard hasMore, !isLoadingMore else { return }
        guard let idx = posts.firstIndex(of: post) else { return }
        let trigger = max(0, posts.count - Self.prefetchTrigger)
        guard idx >= trigger else { return }
        Task { await loadMore() }
    }

    private func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let page = try await repository.fetchFeed(tab: tab, cursor: cursor, limit: Self.pageSize)
            posts.append(contentsOf: page.posts)
            nextCursor = page.nextCursor
            hasMore = page.hasMore
            await mergeReactionSummaries(for: page.posts.map(\.id))
        } catch {
            transientErrorMessage = "Couldn't load more posts."
        }
    }

    /// Batch-fetches per-emoji counts and current-user emoji, then merges into posts.
    /// Failures degrade gracefully — counts stay empty rather than failing the feed.
    private func mergeReactionSummaries(for postIDs: [UUID]) async {
        guard !postIDs.isEmpty else { return }
        do {
            let summaries = try await repository.fetchReactionSummaries(forPostIDs: postIDs)
            let byID = Dictionary(summaries.map { ($0.postID, $0) }, uniquingKeysWith: { a, _ in a })
            for id in postIDs {
                guard let idx = posts.firstIndex(where: { $0.id == id }),
                      let summary = byID[id] else { continue }
                posts[idx].reactionCountsByEmoji = summary.countsByEmoji
                posts[idx].currentUserReaction   = summary.currentUserEmoji
            }
        } catch {
            // Silently degrade: counts stay at default [:], UI falls back to reactions array.
        }
    }

    // MARK: - Realtime

    private func subscribeRealtime() {
        newPostsTask?.cancel()
        let newPostStream = repository.newPostsStream(tab: tab)
        newPostsTask = Task { [weak self] in
            for await post in newPostStream {
                guard let self else { return }
                await MainActor.run {
                    if !self.posts.contains(where: { $0.id == post.id })
                        && !self.pendingNewPosts.contains(where: { $0.id == post.id }) {
                        self.pendingNewPosts.insert(post, at: 0)
                    }
                }
            }
        }

        reactionUpdatesTask?.cancel()
        let reactionStream = repository.reactionUpdatesStream()
        reactionUpdatesTask = Task { [weak self] in
            for await update in reactionStream {
                guard let self else { return }
                await MainActor.run {
                    self.applyReactionUpdate(update)
                }
            }
        }
    }

    private func applyReactionUpdate(_ update: ReactionUpdate) {
        switch update {
        case .added(let reaction):
            guard reaction.userID != currentUserID,
                  let idx = posts.firstIndex(where: { $0.id == reaction.postID }) else { return }
            var post = posts[idx]
            // Remove any prior reaction from this user then add new one.
            if let prior = post.reactions.first(where: { $0.userID == reaction.userID }) {
                post.reactionCountsByEmoji[prior.emoji, default: 1] -= 1
                if post.reactionCountsByEmoji[prior.emoji] == 0 {
                    post.reactionCountsByEmoji.removeValue(forKey: prior.emoji)
                }
                post.reactions.removeAll { $0.userID == reaction.userID }
            }
            post.reactions.append(reaction)
            post.reactionCountsByEmoji[reaction.emoji, default: 0] += 1
            posts[idx] = post

        case .removed(let reactionID, let postID):
            guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
            var post = posts[idx]
            if let removed = post.reactions.first(where: { $0.id == reactionID }) {
                post.reactionCountsByEmoji[removed.emoji, default: 1] -= 1
                if post.reactionCountsByEmoji[removed.emoji] == 0 {
                    post.reactionCountsByEmoji.removeValue(forKey: removed.emoji)
                }
            }
            post.reactions.removeAll { $0.id == reactionID }
            posts[idx] = post
        }
    }

    func applyPendingNewPosts() {
        guard !pendingNewPosts.isEmpty else { return }
        let merged = (pendingNewPosts + posts).sorted { $0.createdAt > $1.createdAt }
        posts = merged
        pendingNewPosts = []
        if phase != .error {
            phase = .loaded
        }
    }

    // MARK: - Reactions

    func toggleReaction(post: Post, emoji: String) {
        let postID = post.id
        let previous = currentUserReaction(in: post)
        let isSame = (previous == emoji)
        let optimisticEmoji: String? = isSame ? nil : emoji

        applyReactionOptimistically(postID: postID, newEmoji: optimisticEmoji)
        activeReactionPicker = nil

        let isCustom = !ReactionEmoji.postPickerSet.contains(emoji)
        if let optimisticEmoji {
            Analytics.track(.postReactionAdded, ["emoji": optimisticEmoji, "post_id": postID.uuidString, "is_custom": isCustom])
        } else {
            Analytics.track(.postReactionRemoved, ["emoji": previous ?? "", "post_id": postID.uuidString])
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                if let optimisticEmoji {
                    try await self.repository.addReaction(postID: postID, emoji: optimisticEmoji)
                } else {
                    try await self.repository.removeReaction(postID: postID)
                }
            } catch {
                await MainActor.run {
                    self.applyReactionOptimistically(postID: postID, newEmoji: previous)
                    self.transientErrorMessage = "Couldn't react. Try again."
                }
            }
        }
    }

    private func currentUserReaction(in post: Post) -> String? {
        if let cached = post.currentUserReaction { return cached }
        return post.reactions.first(where: { $0.userID == currentUserID })?.emoji
    }

    private func applyReactionOptimistically(postID: UUID, newEmoji: String?) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        var post = posts[idx]

        // Adjust count map: decrement old emoji, increment new one.
        let oldEmoji = post.currentUserReaction
            ?? post.reactions.first(where: { $0.userID == currentUserID })?.emoji
        if let old = oldEmoji {
            post.reactionCountsByEmoji[old, default: 1] -= 1
            if post.reactionCountsByEmoji[old] == 0 {
                post.reactionCountsByEmoji.removeValue(forKey: old)
            }
        }
        if let new = newEmoji {
            post.reactionCountsByEmoji[new, default: 0] += 1
        }

        // Keep reactions array in sync for ReactionsBreakdownSheet compatibility.
        post.reactions.removeAll { $0.userID == currentUserID }
        if let newEmoji {
            post.reactions.append(
                Reaction(
                    id: UUID(),
                    postID: postID,
                    userID: currentUserID,
                    username: "you",
                    avatarURL: nil,
                    emoji: newEmoji,
                    createdAt: Date()
                )
            )
        }
        post.currentUserReaction = newEmoji
        posts[idx] = post
    }

    // MARK: - Caption / photos

    func toggleCaptionExpansion(_ postID: UUID) {
        if expandedCaptions.contains(postID) {
            expandedCaptions.remove(postID)
        } else {
            expandedCaptions.insert(postID)
        }
    }

    func featuredIndex(for post: Post) -> Int {
        featuredPhotoIndex[post.id] ?? 0
    }

    func setFeaturedIndex(_ index: Int, for post: Post) {
        featuredPhotoIndex[post.id] = index
    }

    // MARK: - Picker

    func openReactionPicker(for postID: UUID) {
        activeReactionPicker = postID
    }

    func dismissReactionPicker() {
        activeReactionPicker = nil
    }

    func requestCustomEmoji(for postID: UUID) {
        activeReactionPicker = nil
        customEmojiTarget = postID
    }

    func dismissCustomEmoji() {
        customEmojiTarget = nil
    }

    // MARK: - Delete / Report

    func delete(post: Post) {
        let postID = post.id
        posts.removeAll { $0.id == postID }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.deletePost(postID: postID)
            } catch {
                await MainActor.run {
                    self.transientErrorMessage = "Couldn't delete post. Try again."
                }
            }
        }
    }

    func report(post: Post, reason: String = "inappropriate") {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.repository.reportPost(postID: post.id, reason: reason)
                await MainActor.run {
                    self.transientErrorMessage = "Thanks for letting us know."
                }
            } catch {
                await MainActor.run {
                    self.transientErrorMessage = "Couldn't submit report. Try again."
                }
            }
        }
    }

    // MARK: - Helpers

    func clearTransientError() {
        transientErrorMessage = nil
    }

    func isOwnPost(_ post: Post) -> Bool {
        post.user.id == currentUserID
    }

    /// Increments the local comment count on a post when the user submits a top-level
    /// comment, so the badge in PostCard updates without a full feed refetch.
    func incrementCommentCount(postID: UUID) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        posts[idx].commentCount += 1
    }

    private func derivePhase(from page: FeedPage) -> Phase {
        if page.posts.isEmpty {
            return tab == .yesterday ? .yesterdayEmpty : .empty
        }
        if tab == .now, page.ownPostExists,
           !page.posts.contains(where: { $0.user.id != currentUserID }) {
            return .partial
        }
        return .loaded
    }
}
