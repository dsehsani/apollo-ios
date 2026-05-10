//
//  FriendsRepository.swift
//  Apollo
//
//  Protocol + mock for the Friends screen data layer (PRD §07 §7–§8).
//

import Foundation

protocol FriendsRepositoryProtocol: Sendable {
    func fetchFriendsData() async throws -> FriendsData
    func acceptRequest(id: UUID, requesterUserID: UUID) async throws
    func declineRequest(id: UUID) async throws
    func sendFriendRequest(to userID: UUID) async throws
    func dismissRecommendation(id: UUID) async throws
    func searchUsers(query: String) async throws -> [UserSearchResult]
    func fetchAffiliateCode() async throws -> String?
}

enum FriendsRepositoryError: Error, Sendable {
    case network
    case notFound
    case unknown
}

// MARK: - Mock (used in SwiftUI previews only)

struct MockFriendsRepository: FriendsRepositoryProtocol {
    func fetchFriendsData() async throws -> FriendsData {
        try await Task.sleep(for: .milliseconds(300))
        return FriendsData(
            requests: [
                FriendRequest(
                    id: UUID(),
                    requesterUserID: UUID(),
                    displayName: "Jayden Betts",
                    handle: "angryjayden",
                    avatarURL: nil,
                    sourceLabel: "In your contacts"
                )
            ],
            recommended: [
                RecommendedUser(
                    id: UUID(),
                    displayName: "Enoch De Leon",
                    handle: "coool_boy_e",
                    avatarURL: nil,
                    subLabel: "New on Apollo"
                ),
                RecommendedUser(
                    id: UUID(),
                    displayName: "Angel Gomez",
                    handle: "angel_gomez",
                    avatarURL: nil,
                    subLabel: "New on Apollo"
                )
            ],
            contacts: []
        )
    }

    func acceptRequest(id: UUID, requesterUserID: UUID) async throws {}
    func declineRequest(id: UUID) async throws {}
    func sendFriendRequest(to userID: UUID) async throws {}
    func dismissRecommendation(id: UUID) async throws {}
    func searchUsers(query: String) async throws -> [UserSearchResult] { [] }
    func fetchAffiliateCode() async throws -> String? { nil }
}
