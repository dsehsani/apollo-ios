//
//  ProfileModels.swift
//  Apollo
//
//  Data models for the Profile screen (PRD §06).
//  ProfileUser and ProfilePost are distinct from FeedModels so the profile
//  can grow independently (banner photos, friendship state, etc.).
//  PhotoSlot and Reaction are reused from FeedModels.swift.
//

import Foundation

struct ProfileUser: Identifiable, Hashable, Sendable {
    let id: UUID
    var displayName: String
    var handle: String
    var avatarURL: URL?
    var bannerPhotoURLs: [URL]
    var totalWins: Int
    var streak: Int
    var friendCount: Int
    var isCurrentUser: Bool
}

struct ProfilePost: Identifiable, Hashable, Sendable {
    let id: UUID
    var winsCount: Int
    var mainPhotoURL: URL?
    var towerPhotos: [PhotoSlot]
    var caption: String
    var reactions: [Reaction]
    var commentCount: Int
}

enum FriendshipStatus: Sendable {
    case currentUser
    case friends
    case notFriends
    case requested
    case blocked
}
