//
//  CommentsRepository.swift
//  Apollo
//
//  Abstraction over the Comments data source. CommentsViewModel talks only to
//  this protocol; concrete implementations can be swapped without touching UI.
//

import Foundation

protocol CommentsRepository: Sendable {
    var currentUserID: UUID { get }
    /// Minimal user record for the current user (avatar, username) used in the input bar.
    var currentUser: CommentUser { get }

    /// Fetch up to `limit` comments for a post, ordered newest-first for top-level,
    /// oldest-first for replies. Pass `before` for cursor pagination.
    func fetchComments(postID: UUID, before: Date?, limit: Int) async throws -> [Comment]

    /// Insert a new comment. Pass `parentID` for a reply.
    func postComment(postID: UUID, text: String, parentID: UUID?) async throws -> Comment

    /// Delete own comment. Throws `.forbidden` if caller doesn't own the comment.
    func deleteComment(commentID: UUID) async throws

    /// Realtime stream of new comments posted by others on this post.
    func newCommentsStream(postID: UUID) -> AsyncStream<Comment>
}
