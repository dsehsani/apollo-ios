//
//  FriendsViewModel.swift
//  Apollo
//
//  @Observable view model for FriendsView (PRD §07).
//

import Foundation
import Observation

@Observable
final class FriendsViewModel {

    enum Phase {
        case loading
        case loaded(FriendsData)
        case error(String)
    }

    private(set) var phase: Phase = .loading
    var searchText: String = ""

    private let repository: any FriendsRepositoryProtocol

    init(repository: any FriendsRepositoryProtocol = MockFriendsRepository()) {
        self.repository = repository
    }

    // MARK: - Load

    func load() async {
        phase = .loading
        do {
            let data = try await repository.fetchFriendsData()
            phase = .loaded(data)
        } catch {
            phase = .error("Couldn't load friends. Try again.")
        }
    }

    func refresh() async {
        do {
            let data = try await repository.fetchFriendsData()
            phase = .loaded(data)
        } catch {
            phase = .error("Couldn't load friends. Try again.")
        }
    }

    // MARK: - Requests

    func acceptRequest(_ request: FriendRequest) {
        guard case .loaded(var data) = phase else { return }
        data.requests.removeAll { $0.id == request.id }
        phase = .loaded(data)
        Task { try? await repository.acceptRequest(id: request.id) }
    }

    func declineRequest(_ request: FriendRequest) {
        guard case .loaded(var data) = phase else { return }
        data.requests.removeAll { $0.id == request.id }
        phase = .loaded(data)
        Task { try? await repository.declineRequest(id: request.id) }
    }

    // MARK: - Recommended

    func addRecommended(_ user: RecommendedUser) {
        guard case .loaded(var data) = phase else { return }
        if let idx = data.recommended.firstIndex(where: { $0.id == user.id }) {
            data.recommended[idx].hasRequested = true
        }
        phase = .loaded(data)
        Task { try? await repository.sendFriendRequest(to: user.id) }
    }

    func dismissRecommended(_ user: RecommendedUser) {
        guard case .loaded(var data) = phase else { return }
        data.recommended.removeAll { $0.id == user.id }
        phase = .loaded(data)
        Task { try? await repository.dismissRecommendation(id: user.id) }
    }
}
