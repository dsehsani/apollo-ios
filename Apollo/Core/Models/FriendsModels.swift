//
//  FriendsModels.swift
//  Apollo
//
//  Data models for the Friends screen (PRD §07).
//

import Foundation

struct FriendRequest: Identifiable, Hashable, Sendable {
    let id: UUID
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
