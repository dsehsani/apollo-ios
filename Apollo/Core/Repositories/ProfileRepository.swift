//
//  ProfileRepository.swift
//  Apollo
//
//  Protocol + mock for the Profile screen data layer (PRD §06 §7–§8).
//

import Foundation

protocol ProfileRepositoryProtocol: Sendable {
    func fetchProfile(userID: UUID) async throws -> (ProfileUser, ProfilePost?)
    func uploadAvatar(_ data: Data) async throws -> URL
    func uploadBannerPhoto(_ data: Data) async throws -> URL
    func setBannerPhotos(_ urls: [URL], type: String) async throws
    func fetchOwnRecentWinPhotos(limit: Int) async throws -> [URL]
}

// Default no-op stubs so mocks only need to override what they care about.
extension ProfileRepositoryProtocol {
    func uploadAvatar(_ data: Data) async throws -> URL {
        throw ProfileRepositoryError.unknown
    }
    func uploadBannerPhoto(_ data: Data) async throws -> URL {
        throw ProfileRepositoryError.unknown
    }
    func setBannerPhotos(_ urls: [URL], type: String) async throws {
        throw ProfileRepositoryError.unknown
    }
    func fetchOwnRecentWinPhotos(limit: Int) async throws -> [URL] {
        throw ProfileRepositoryError.unknown
    }
}

enum ProfileRepositoryError: Error, Sendable {
    case network
    case notFound
    case unknown
    case compressionFailed
    case uploadFailed(reason: String)
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
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "darius_ehsani", avatarURL: nil, emoji: "❤️", createdAt: .now),
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "riley", avatarURL: nil, emoji: "🔥", createdAt: .now),
                Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "mira", avatarURL: nil, emoji: "👑", createdAt: .now),
            ],
            commentCount: 4
        )

        return (user, post)
    }
}
