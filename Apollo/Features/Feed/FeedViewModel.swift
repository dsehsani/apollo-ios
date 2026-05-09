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

    private let repository: FeedRepository

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
    var transientErrorMessage: String?

    private var newPostsTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    var currentUserID: UUID { repository.currentUserID }
    var pendingNewPostsCount: Int { pendingNewPosts.count }

    init(repository: FeedRepository) {
        self.repository = repository
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
        } catch {
            transientErrorMessage = "Couldn't load more posts."
        }
    }

    // MARK: - Realtime

    private func subscribeRealtime() {
        newPostsTask?.cancel()
        let stream = repository.newPostsStream(tab: tab)
        newPostsTask = Task { [weak self] in
            for await post in stream {
                guard let self else { return }
                await MainActor.run {
                    if !self.posts.contains(where: { $0.id == post.id })
                        && !self.pendingNewPosts.contains(where: { $0.id == post.id }) {
                        self.pendingNewPosts.insert(post, at: 0)
                    }
                }
            }
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

    func toggleReaction(post: Post, emoji: ReactionEmoji) {
        let postID = post.id
        let previous = currentUserReaction(in: post)
        let isSame = (previous == emoji)
        let optimisticEmoji: ReactionEmoji? = isSame ? nil : emoji

        applyReactionOptimistically(postID: postID, newEmoji: optimisticEmoji)
        activeReactionPicker = nil

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

    private func currentUserReaction(in post: Post) -> ReactionEmoji? {
        if let cached = post.currentUserReaction { return cached }
        return post.reactions.first(where: { $0.userID == currentUserID })?.emoji
    }

    private func applyReactionOptimistically(postID: UUID, newEmoji: ReactionEmoji?) {
        guard let idx = posts.firstIndex(where: { $0.id == postID }) else { return }
        var post = posts[idx]
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
