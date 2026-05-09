//
//  FeedModels.swift
//  Apollo
//
//  Shared data models for the Feed screen. Shapes mirror PRD section 7.
//

import Foundation

let MaxPhotosPerDay: Int = 6

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

    static let pickerOrder: [ReactionEmoji] = [.heart, .fire, .crown]
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
    var currentUserReaction: ReactionEmoji?

    var reactionsByEmoji: [ReactionEmoji: Int] {
        Dictionary(grouping: reactions, by: { $0.emoji }).mapValues { $0.count }
    }
}

struct Reaction: Identifiable, Hashable, Sendable {
    let id: UUID
    var postID: UUID
    var userID: UUID
    var username: String
    var avatarURL: URL?
    var emoji: ReactionEmoji
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
