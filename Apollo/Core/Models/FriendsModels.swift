//
//  FriendsModels.swift
//  Apollo
//
//  Data models for the Friends screen (PRD §07).
//

import Foundation

struct FriendRequest: Identifiable, Hashable, Sendable {
    let id: UUID
    /// The auth/users.id of the person who sent the request (needed for reverse-row insert on accept).
    let requesterUserID: UUID
    var displayName: String
    var handle: String
    var avatarURL: URL?
    var sourceLabel: String   // e.g. "In your contacts"
}

struct RecommendedUser: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var handle: String
    var avatarURL: URL?
    var subLabel: String      // e.g. "7 Mutuals" or "In your contacts"
    var hasRequested: Bool = false
}

struct InviteContact: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var handle: String        // shown as username / phone stub; "Not here yet" shown as subline
    var avatarURL: URL?
}

struct FriendsData: Sendable {
    var requests: [FriendRequest]
    var recommended: [RecommendedUser]
    var contacts: [InviteContact]
}

// MARK: - Friendship state for search results

enum FriendshipState: Hashable, Sendable {
    case none
    case requestedByMe
    case incomingRequest(friendshipID: UUID)
    case friends
}

struct UserSearchResult: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var handle: String
    var avatarURL: URL?
    var state: FriendshipState
}
