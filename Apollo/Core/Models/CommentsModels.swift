//
//  CommentsModels.swift
//  Apollo
//
//  Shared data models for the Comments system. Shapes mirror PRD §09 section 7.
//

import Foundation

// MARK: - User

struct CommentUser: Identifiable, Hashable, Sendable {
    let id: UUID
    var username: String
    var avatarURL: URL?
}

// MARK: - Reaction

struct CommentReaction: Identifiable, Hashable, Sendable {
    let id: UUID
    var commentID: UUID
    var userID: UUID
    var username: String
    var avatarURL: URL?
    /// Raw emoji character — e.g. "❤️", "👅", "😂", or any custom emoji.
    var emoji: String
    var createdAt: Date
}

// MARK: - Comment

struct Comment: Identifiable, Hashable, Sendable {
    let id: UUID
    var postID: UUID
    var userID: UUID
    var user: CommentUser
    var text: String
    var createdAt: Date
    /// nil for top-level comments. Set to parent id for replies (1 level max in v1).
    var parentID: UUID?
    var reactions: [CommentReaction]
    var replyCount: Int
}

// MARK: - Pagination cursor

struct CommentCursor: Hashable, Sendable {
    var createdAt: Date
    var id: UUID
}

// MARK: - Errors

enum CommentsRepositoryError: Error, Sendable {
    case network
    case notFound
    case forbidden
    case profanityBlocked
    case unknown
}
