//
//  SupabaseCommentsRepository.swift
//  Apollo
//
//  Supabase-backed CommentsRepository. fetchComments queries the `comments` table
//  joined to `users`. postComment inserts into `comments`. newCommentsStream is
//  stubbed until Realtime is wired up.
//

import Foundation
import Supabase

// MARK: - Decodable row shapes

/// Embedded `users(...)` from PostgREST is a nested object (not flattened).
private struct CommentAuthorEmbed: Decodable {
    let username: String
    let avatar_url: String?
}

private struct CommentDBRow: Decodable {
    let id: UUID
    let post_id: UUID
    let user_id: UUID
    let text: String
    let created_at: String
    let parent_id: UUID?
    let users: CommentAuthorEmbed?

    enum CodingKeys: String, CodingKey {
        case id, post_id, user_id, text, created_at, parent_id, users
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        post_id = try c.decode(UUID.self, forKey: .post_id)
        user_id = try c.decode(UUID.self, forKey: .user_id)
        text = try c.decode(String.self, forKey: .text)
        created_at = try c.decode(String.self, forKey: .created_at)
        parent_id = try c.decodeIfPresent(UUID.self, forKey: .parent_id)
        if let embed = try? c.decode(CommentAuthorEmbed.self, forKey: .users) {
            users = embed
        } else if let arr = try? c.decode([CommentAuthorEmbed].self, forKey: .users), let first = arr.first {
            users = first
        } else {
            users = nil
        }
    }
}

// MARK: - Repository

final class SupabaseCommentsRepository: CommentsRepository, @unchecked Sendable {

    let currentUserID: UUID
    let currentUser: CommentUser

    init(currentUserID: UUID, username: String, avatarURL: URL? = nil) {
        self.currentUserID = currentUserID
        self.currentUser   = CommentUser(id: currentUserID, username: username, avatarURL: avatarURL)
    }

    // MARK: - fetchComments

    func fetchComments(postID: UUID, before: Date?, limit: Int) async throws -> [Comment] {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var query = supabase
            .from("comments")
            .select("""
                id, post_id, user_id, text, created_at, parent_id,
                users(username, avatar_url)
            """)
            .eq("post_id", value: postID)
            .is("deleted_at", value: Bool?.none)

        if let before {
            query = query.lt("created_at", value: iso.string(from: before))
        }

        let response = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()

        let decoder = JSONDecoder()
        let rows = try decoder.decode([CommentDBRow].self, from: response.data)
        return rows.map(mapRow)
    }

    // MARK: - postComment

    func postComment(postID: UUID, text: String, parentID: UUID?) async throws -> Comment {
        struct CommentInsert: Encodable {
            let post_id: UUID
            let user_id: UUID
            let text: String
            let parent_id: UUID?
        }

        let row = CommentInsert(
            post_id: postID,
            user_id: currentUserID,
            text: text,
            parent_id: parentID
        )

        let response = try await supabase
            .from("comments")
            .insert(row)
            .select("""
                id, post_id, user_id, text, created_at, parent_id,
                users(username, avatar_url)
            """)
            .single()
            .execute()

        let decoder = JSONDecoder()
        let commentRow = try decoder.decode(CommentDBRow.self, from: response.data)
        return mapRow(commentRow)
    }

    // MARK: - deleteComment

    func deleteComment(commentID: UUID) async throws {
        struct SoftDelete: Encodable { let deleted_at: String }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        try await supabase
            .from("comments")
            .update(SoftDelete(deleted_at: iso.string(from: Date())))
            .eq("id", value: commentID)
            .eq("user_id", value: currentUserID)
            .execute()
    }

    // MARK: - newCommentsStream (stubbed until Realtime is wired)

    func newCommentsStream(postID: UUID) -> AsyncStream<Comment> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    // MARK: - Row mappers

    private func mapRow(_ r: CommentDBRow) -> Comment {
        let author = r.users
        let username = author?.username ?? "user"
        let avatarURL = author?.avatar_url.flatMap(URL.init(string:))
        return Comment(
            id: r.id,
            postID: r.post_id,
            userID: r.user_id,
            user: CommentUser(
                id: r.user_id,
                username: username,
                avatarURL: avatarURL
            ),
            text: r.text,
            createdAt: parseTimestamp(r.created_at) ?? Date(),
            parentID: r.parent_id,
            reactions: [],
            replyCount: 0
        )
    }

    private func parseTimestamp(_ raw: String) -> Date? {
        let normalised = raw.replacingOccurrences(of: " ", with: "T")

        let isoFull = ISO8601DateFormatter()
        isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFull.date(from: normalised) { return d }

        let isoSec = ISO8601DateFormatter()
        isoSec.formatOptions = [.withInternetDateTime]
        return isoSec.date(from: normalised)
    }
}
