//
//  MockCommentsRepository.swift
//  Apollo
//
//  In-memory CommentsRepository with realistic seeded data, simulated latency,
//  profanity detection, and a realtime stream that fires one incoming comment
//  after ~6s. Used by Xcode Previews and SwiftUI canvas.
//

import Foundation

final class MockCommentsRepository: CommentsRepository, @unchecked Sendable {

    enum ForcedState: Sendable {
        case populated
        case empty
        case error
    }

    let currentUserID: UUID
    let currentUser: CommentUser

    private let forced: ForcedState
    private let lock = NSLock()
    private var comments: [Comment] = []
    private var seededPostIDs: Set<UUID> = []

    // MARK: - Init

    init(forceState: ForcedState = .populated) {
        let me = MockCommentsRepository.meUser
        self.currentUserID = me.id
        self.currentUser   = me
        self.forced        = forceState
    }

    // MARK: - CommentsRepository

    func fetchComments(postID: UUID, before: Date?, limit: Int) async throws -> [Comment] {
        try await Task.sleep(nanoseconds: 300_000_000)
        if forced == .error { throw CommentsRepositoryError.network }

        let result = lock.withLock { () -> [Comment] in
            // Lazy-seed on first fetch for this postID so the shared repo works
            // for any post without needing postID at init time.
            if forced == .populated && !seededPostIDs.contains(postID) {
                comments.append(contentsOf: Self.makeComments(postID: postID))
                seededPostIDs.insert(postID)
            }

            let sorted = comments
                .filter { $0.postID == postID }
                .sorted { $0.createdAt > $1.createdAt }

            let filtered: [Comment]
            if let before {
                filtered = sorted.filter { $0.createdAt < before }
            } else {
                filtered = sorted
            }
            return Array(filtered.prefix(limit))
        }

        return result
    }

    func postComment(postID: UUID, text: String, parentID: UUID?) async throws -> Comment {
        try await Task.sleep(nanoseconds: 250_000_000)
        if forced == .error { throw CommentsRepositoryError.network }

        let lower = text.lowercased()
        let blocked = ["fuck", "shit", "ass", "bitch"]
        if blocked.contains(where: { lower.contains($0) }) {
            throw CommentsRepositoryError.profanityBlocked
        }

        let comment = Comment(
            id: UUID(),
            postID: postID,
            userID: currentUserID,
            user: currentUser,
            text: text,
            createdAt: Date(),
            parentID: parentID,
            reactions: [],
            replyCount: 0
        )

        lock.withLock {
            comments.insert(comment, at: 0)
            if let parentID {
                if let idx = comments.firstIndex(where: { $0.id == parentID }) {
                    comments[idx].replyCount += 1
                }
            }
        }
        return comment
    }

    func deleteComment(commentID: UUID) async throws {
        try await Task.sleep(nanoseconds: 200_000_000)
        if forced == .error { throw CommentsRepositoryError.network }

        lock.withLock {
            guard let idx = comments.firstIndex(where: { $0.id == commentID }) else { return }
            let comment = comments[idx]
            if comment.userID != currentUserID {
                return // would throw .forbidden in prod
            }
            comments.remove(at: idx)
            if let parentID = comment.parentID,
               let parentIdx = comments.firstIndex(where: { $0.id == parentID }) {
                comments[parentIdx].replyCount = max(0, comments[parentIdx].replyCount - 1)
            }
        }
    }

    func newCommentsStream(postID: UUID) -> AsyncStream<Comment> {
        let repo = self
        return AsyncStream { continuation in
            let task = Task {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { continuation.finish(); return }
                if repo.forced == .populated {
                    let incoming = MockCommentsRepository.makeIncomingComment(postID: postID)
                    repo.lock.withLock { repo.comments.insert(incoming, at: 0) }
                    continuation.yield(incoming)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Fixtures

    static let meUser = CommentUser(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000aa")!,
        username: "darius",
        avatarURL: URL(string: "https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=400")
    )

    private static let users: [CommentUser] = [
        CommentUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b1")!,
            username: "jayden",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400")
        ),
        CommentUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b2")!,
            username: "rildy",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400")
        ),
        CommentUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b3")!,
            username: "mira",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=400")
        ),
        CommentUser(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000b4")!,
            username: "leo",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1527980965255-d3b416303d12?w=400")
        ),
    ]

    private static func makeComments(postID: UUID) -> [Comment] {
        let now  = Date()
        let c1ID = UUID()
        let c2ID = UUID()
        let c3ID = UUID()
        let c4ID = UUID()
        let r1ID = UUID()
        let r2ID = UUID()

        return [
            // newest top-level first
            Comment(
                id: c4ID,
                postID: postID,
                userID: users[3].id,
                user: users[3],
                text: "Genuinely inspired by this one. Setting my alarm for 6am.",
                createdAt: now.addingTimeInterval(-5 * 60),
                parentID: nil,
                reactions: [],
                replyCount: 0
            ),
            Comment(
                id: c3ID,
                postID: postID,
                userID: users[2].id,
                user: users[2],
                text: "The streak stays alive! 🔥",
                createdAt: now.addingTimeInterval(-15 * 60),
                parentID: nil,
                reactions: [],
                replyCount: 0
            ),
            // reply to c2
            Comment(
                id: r2ID,
                postID: postID,
                userID: users[1].id,
                user: users[1],
                text: "@jayden haha yes exactly, that's the whole game",
                createdAt: now.addingTimeInterval(-30 * 60),
                parentID: c2ID,
                reactions: [],
                replyCount: 0
            ),
            Comment(
                id: r1ID,
                postID: postID,
                userID: meUser.id,
                user: meUser,
                text: "@jayden seriously though, every single day",
                createdAt: now.addingTimeInterval(-35 * 60),
                parentID: c2ID,
                reactions: [],
                replyCount: 0
            ),
            Comment(
                id: c2ID,
                postID: postID,
                userID: users[0].id,
                user: users[0],
                text: "Show up — that's the whole game. You're living proof.",
                createdAt: now.addingTimeInterval(-45 * 60),
                parentID: nil,
                reactions: [],
                replyCount: 2
            ),
            Comment(
                id: c1ID,
                postID: postID,
                userID: users[1].id,
                user: users[1],
                text: "This is the type of W that compounds. Keep stacking.",
                createdAt: now.addingTimeInterval(-2 * 3600),
                parentID: nil,
                reactions: [],
                replyCount: 0
            ),
        ]
    }

    private static func makeIncomingComment(postID: UUID) -> Comment {
        Comment(
            id: UUID(),
            postID: postID,
            userID: users[2].id,
            user: users[2],
            text: "Just caught this. Absolute fire — you're on a different level.",
            createdAt: Date(),
            parentID: nil,
            reactions: [],
            replyCount: 0
        )
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
