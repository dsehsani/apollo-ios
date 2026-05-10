//
//  CommentsViewModel.swift
//  Apollo
//
//  One @Observable ViewModel per screen (Apollo convention). Owns the full
//  comments lifecycle: loading, optimistic submit/delete, reply state,
//  pagination, and realtime new-comment injection.
//

import Foundation
import Observation

@Observable
@MainActor
final class CommentsViewModel {

    enum Phase: Equatable {
        case loading
        case loaded
        case error
    }

    private static let pageSize = 20
    private static let prefetchTrigger = 3

    // MARK: - State

    let repository: CommentsRepository
    let postID: UUID
    let postOwnerUsername: String

    var phase: Phase = .loading
    var comments: [Comment] = []
    var hasMore: Bool = false
    private var oldestCursor: Date?

    var isLoadingMore: Bool = false
    var inputText: String = ""
    var replyTo: Comment?
    var transientErrorMessage: String?
    var deleteCandidate: Comment?

    private var realtimeTask: Task<Void, Never>?

    // MARK: - Init

    init(postID: UUID, postOwnerUsername: String, repository: CommentsRepository) {
        self.postID              = postID
        self.postOwnerUsername   = postOwnerUsername
        self.repository          = repository
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await load() }
        subscribeRealtime()
    }

    func onDisappear() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    // MARK: - Loading

    func load() async {
        phase = .loading
        comments = []
        oldestCursor = nil
        hasMore = false

        do {
            let fetched = try await repository.fetchComments(
                postID: postID,
                before: nil,
                limit: Self.pageSize
            )
            apply(fetched: fetched, appending: false)
            phase = .loaded
        } catch {
            phase = .error
            transientErrorMessage = "Couldn't load comments."
        }
    }

    func loadMoreIfNeeded(currentComment comment: Comment) {
        guard hasMore, !isLoadingMore else { return }
        // Only trigger from top-level comments (replies are inline)
        let topLevel = displayedComments.filter { $0.parentID == nil }
        guard let idx = topLevel.firstIndex(where: { $0.id == comment.id }) else { return }
        let trigger = max(0, topLevel.count - Self.prefetchTrigger)
        guard idx >= trigger else { return }
        Task { await loadMore() }
    }

    private func loadMore() async {
        guard !isLoadingMore, let cursor = oldestCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let fetched = try await repository.fetchComments(
                postID: postID,
                before: cursor,
                limit: Self.pageSize
            )
            apply(fetched: fetched, appending: true)
        } catch {
            transientErrorMessage = "Couldn't load more comments."
        }
    }

    private func apply(fetched: [Comment], appending: Bool) {
        if appending {
            let existingIDs = Set(comments.map(\.id))
            let newOnes = fetched.filter { !existingIDs.contains($0.id) }
            comments.append(contentsOf: newOnes)
        } else {
            comments = fetched
        }
        hasMore = fetched.count >= Self.pageSize
        if let oldest = fetched.map(\.createdAt).min() {
            if !appending || (oldestCursor.map { oldest < $0 } ?? true) {
                oldestCursor = oldest
            }
        }
    }

    // MARK: - Realtime

    private func subscribeRealtime() {
        realtimeTask?.cancel()
        let stream = repository.newCommentsStream(postID: postID)
        realtimeTask = Task { [weak self] in
            for await comment in stream {
                guard let self else { return }
                await MainActor.run {
                    guard !self.comments.contains(where: { $0.id == comment.id }) else { return }
                    self.comments.insert(comment, at: 0)
                }
            }
        }
    }

    // MARK: - Displayed list

    /// Flat ordered list: top-level newest-first, replies inserted oldest-first
    /// directly after their parent comment (v1, 1 level deep).
    var displayedComments: [Comment] {
        let topLevel = comments
            .filter { $0.parentID == nil }
            .sorted { $0.createdAt > $1.createdAt }

        var result: [Comment] = []
        for parent in topLevel {
            result.append(parent)
            let replies = comments
                .filter { $0.parentID == parent.id }
                .sorted { $0.createdAt < $1.createdAt }
            result.append(contentsOf: replies)
        }
        return result
    }

    // MARK: - Submit

    func submit() {
        let rawText = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawText.isEmpty else { return }

        let parentID = replyTo?.id
        let tempID   = UUID()
        let temp     = Comment(
            id: tempID,
            postID: postID,
            userID: repository.currentUserID,
            user: repository.currentUser,
            text: rawText,
            createdAt: Date(),
            parentID: parentID,
            reactions: [],
            replyCount: 0
        )

        inputText = ""
        cancelReply()

        comments.insert(temp, at: 0)

        Analytics.track(.commentSubmitted, [
            "post_id": postID.uuidString,
            "character_count": rawText.count,
            "is_reply": parentID != nil
        ])

        Task { [weak self] in
            guard let self else { return }
            do {
                let confirmed = try await repository.postComment(
                    postID: postID,
                    text: rawText,
                    parentID: parentID
                )
                await MainActor.run {
                    if let idx = self.comments.firstIndex(where: { $0.id == tempID }) {
                        self.comments[idx] = confirmed
                    }
                }
            } catch CommentsRepositoryError.profanityBlocked {
                await MainActor.run {
                    self.comments.removeAll { $0.id == tempID }
                    self.transientErrorMessage = "That comment can't be posted."
                }
            } catch {
                await MainActor.run {
                    self.comments.removeAll { $0.id == tempID }
                    self.transientErrorMessage = "Couldn't post comment. Try again."
                }
            }
        }
    }

    // MARK: - Reply

    func startReply(to comment: Comment) {
        replyTo  = comment
        inputText = "@\(comment.user.username) "
        Analytics.track(.replyStarted, ["post_id": postID.uuidString])
    }

    func cancelReply() {
        replyTo = nil
        if inputText.hasPrefix("@") {
            inputText = ""
        }
    }

    // MARK: - Delete

    func delete(comment: Comment) {
        let id = comment.id
        comments.removeAll { $0.id == id }

        Analytics.track(.commentDeleted, ["post_id": postID.uuidString])

        Task { [weak self] in
            guard let self else { return }
            do {
                try await repository.deleteComment(commentID: id)
            } catch {
                await MainActor.run {
                    self.comments.insert(comment, at: 0)
                    self.transientErrorMessage = "Couldn't delete. Try again."
                }
            }
        }
    }

    // MARK: - Helpers

    func clearTransientError() {
        transientErrorMessage = nil
    }

    func isOwnComment(_ comment: Comment) -> Bool {
        comment.userID == repository.currentUserID
    }
}
