//
//  ProfileRepository.swift
//  Apollo
//
//  Protocol + mock for the Profile screen data layer (PRD §06 §7–§8).
//

import Foundation

protocol ProfileRepositoryProtocol: Sendable {
    func fetchProfile(userID: UUID) async throws -> (ProfileUser, ProfilePost?)
}

enum ProfileRepositoryError: Error, Sendable {
    case network
    case notFound
    case unknown
}

// MARK: - Mock

struct MockProfileRepository: ProfileRepositoryProtocol {
    func fetchProfile(userID: UUID) async throws -> (ProfileUser, ProfilePost?) {
        try await Task.sleep(for: .milliseconds(400))

        let user = ProfileUser(
            id: userID,
            displayName: "Jayden Betts",
            handle: "jaydenbetts",
            avatarURL: nil,
            bannerPhotoURLs: [],
            totalWins: 47,
            streak: 14,
            friendCount: 12,
            isCurrentUser: true
        )

        let post = ProfilePost(
            id: UUID(),
            winsCount: 8,
            mainPhotoURL: nil,
            towerPhotos: [
                PhotoSlot(id: UUID(), url: nil, index: 1),
                PhotoSlot(id: UUID(), url: nil, index: 2),
                PhotoSlot(id: UUID(), url: nil, index: 3),
            ],
            caption: "church, hike, and more",
            reactions: [
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "darius_ehsani", avatarURL: nil, emoji: .heart, createdAt: .now),
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "riley", avatarURL: nil, emoji: .fire, createdAt: .now),
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "mira", avatarURL: nil, emoji: .crown, createdAt: .now),
            ],
            commentCount: 4
        )

        return (user, post)
    }
}
