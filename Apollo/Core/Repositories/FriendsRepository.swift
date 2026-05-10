//
//  FriendsRepository.swift
//  Apollo
//
//  Protocol + mock for the Friends screen data layer (PRD §07 §7–§8).
//

import Foundation

protocol FriendsRepositoryProtocol: Sendable {
    func fetchFriendsData() async throws -> FriendsData
    func acceptRequest(id: UUID) async throws
    func declineRequest(id: UUID) async throws
    func sendFriendRequest(to userID: UUID) async throws
    func dismissRecommendation(id: UUID) async throws
}

enum FriendsRepositoryError: Error, Sendable {
    case network
    case notFound
    case unknown
}

// MARK: - Mock

struct MockFriendsRepository: FriendsRepositoryProtocol {
    func fetchFriendsData() async throws -> FriendsData {
        try await Task.sleep(for: .milliseconds(300))
        return FriendsData(
            requests: [
                FriendRequest(
                    id: UUID(),
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
                    subLabel: "In your contacts"
                ),
                RecommendedUser(
                    id: UUID(),
                    displayName: "Angel Gomez",
                    handle: "angel_gomez",
                    avatarURL: nil,
                    subLabel: "7 Mutuals"
                ),
                RecommendedUser(
                    id: UUID(),
                    displayName: "Marge Kellogg",
                    handle: "grandma_vibes",
                    avatarURL: nil,
                    subLabel: "10 Mutuals"
                ),
                RecommendedUser(
                    id: UUID(),
                    displayName: "Rildy Gomez",
                    handle: "rildygomez",
                    avatarURL: nil,
                    subLabel: "In your contacts"
                )
            ],
            contacts: [
                InviteContact(id: UUID(), displayName: "Yao Ming",       handle: "yaoming89",   avatarURL: nil),
                InviteContact(id: UUID(), displayName: "Jayden Belts",   handle: "lockedin",    avatarURL: nil),
                InviteContact(id: UUID(), displayName: "Lebron James",   handle: "lebronjames", avatarURL: nil),
                InviteContact(id: UUID(), displayName: "jaden_bots",     handle: "jaden_bots",  avatarURL: nil)
            ]
        )
    }

    func acceptRequest(id: UUID) async throws {}
    func declineRequest(id: UUID) async throws {}
    func sendFriendRequest(to userID: UUID) async throws {}
    func dismissRecommendation(id: UUID) async throws {}
}
