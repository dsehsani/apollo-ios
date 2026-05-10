//
//  FeedModels.swift
//  Apollo
//
//  Shared data models for the Feed screen. Shapes mirror PRD section 7.
//

import Foundation

nonisolated let MaxPhotosPerDay: Int = 6

enum FeedTab: String, CaseIterable, Hashable, Sendable {
    case now
    case yesterday

    var title: String {
        switch self {
        case .now: return "Now"
        case .yesterday: return "Yesterday"
        }
    }
}

enum ReactionEmoji: String, CaseIterable, Hashable, Sendable {
    case heart = "❤️"
    case fire = "🔥"
    case crown = "👑"

    static let postPickerOrder: [ReactionEmoji] = [.heart, .fire, .crown]

    /// All standard post-picker emoji raw values. Used to distinguish custom reactions.
    static var postPickerSet: Set<String> { Set(allCases.map(\.rawValue)) }
}

enum ReactionUpdate: Sendable {
    case added(Reaction)
    case removed(reactionID: UUID, postID: UUID)
}

struct PostUser: Identifiable, Hashable, Sendable {
    let id: UUID
    var username: String
    var avatarURL: URL?
    var streak: Int
}

struct PhotoSlot: Identifiable, Hashable, Sendable {
    let id: UUID
    var url: URL?
    var index: Int
}

struct Post: Identifiable, Hashable, Sendable {
    let id: UUID
    var user: PostUser
    var createdAt: Date
    var caption: String
    var photoCount: Int
    var mainPhotoURL: URL?
    var towerPhotos: [PhotoSlot]
    var winsCount: Int
    var reactions: [Reaction]
    var commentCount: Int
    /// Raw emoji string for the current user's reaction, e.g. "❤️" or "🦾" for custom.
    var currentUserReaction: String?
    /// Authoritative emoji → count map loaded from Supabase. Empty until populated.
    var reactionCountsByEmoji: [String: Int]

    init(
        id: UUID,
        user: PostUser,
        createdAt: Date,
        caption: String,
        photoCount: Int,
        mainPhotoURL: URL?,
        towerPhotos: [PhotoSlot],
        winsCount: Int,
        reactions: [Reaction],
        commentCount: Int,
        currentUserReaction: String?,
        reactionCountsByEmoji: [String: Int] = [:]
    ) {
        self.id = id
        self.user = user
        self.createdAt = createdAt
        self.caption = caption
        self.photoCount = photoCount
        self.mainPhotoURL = mainPhotoURL
        self.towerPhotos = towerPhotos
        self.winsCount = winsCount
        self.reactions = reactions
        self.commentCount = commentCount
        self.currentUserReaction = currentUserReaction
        self.reactionCountsByEmoji = reactionCountsByEmoji
    }

    var reactionsByEmoji: [String: Int] {
        Dictionary(grouping: reactions, by: { $0.emoji }).mapValues { $0.count }
    }

    /// Display-ordered pairs for the reaction strip. When `reactionCountsByEmoji`
    /// is populated (Supabase data) it is used; otherwise falls back to `reactions`
    /// so previews and mock data continue to work without fixture changes.
    var orderedReactionCounts: [(emoji: String, count: Int)] {
        let source = reactionCountsByEmoji.isEmpty ? reactionsByEmoji : reactionCountsByEmoji
        return source
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .map { (emoji: $0.key, count: $0.value) }
    }
}

/// Aggregated per-post reaction data fetched from Supabase in a single batch.
struct PostReactionSummary: Sendable {
    let postID: UUID
    var countsByEmoji: [String: Int]
    var currentUserEmoji: String?
}

struct Reaction: Identifiable, Hashable, Sendable {
    let id: UUID
    var postID: UUID
    var userID: UUID
    var username: String
    var avatarURL: URL?
    /// Raw emoji character string — e.g. "❤️", "🔥", "👑", or any custom emoji.
    var emoji: String
    var createdAt: Date
}

struct CommentSummary: Hashable, Sendable {
    var postID: UUID
    var count: Int
}

struct Quote: Hashable, Sendable {
    var text: String
    var date: Date
}

struct FeedCursor: Hashable, Sendable {
    var createdAt: Date
    var id: UUID
}

struct FeedPage: Sendable {
    var posts: [Post]
    var nextCursor: FeedCursor?
    var hasMore: Bool
    var ownPostExists: Bool
}

enum FeedRepositoryError: Error, Sendable {
    case network
    case notFound
    case forbidden
    case unknown
}
