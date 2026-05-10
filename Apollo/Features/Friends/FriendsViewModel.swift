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
    var searchText: String = "" {
        didSet { scheduleSearch() }
    }
    private(set) var searchResults: [UserSearchResult] = []
    private(set) var isSearching: Bool = false
    private(set) var searchError: String? = nil
    private(set) var affiliateCode: String? = nil
    var toastMessage: String? = nil

    private let repository: any FriendsRepositoryProtocol
    private var searchTask: Task<Void, Never>? = nil

    init(currentUserID: UUID) {
        self.repository = SupabaseFriendsRepository(currentUserID: currentUserID)
    }

    /// Preview / test initialiser that accepts an injected repository.
    init(repository: any FriendsRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Load

    func load() async {
        phase = .loading
        do {
            async let dataTask = repository.fetchFriendsData()
            async let codeTask = repository.fetchAffiliateCode()
            let (data, code) = try await (dataTask, codeTask)
            phase = .loaded(data)
            affiliateCode = code
        } catch {
            phase = .error("Couldn't load friends. Try again.")
        }
    }

    func refresh() async {
        do {
            async let dataTask = repository.fetchFriendsData()
            async let codeTask = repository.fetchAffiliateCode()
            let (data, code) = try await (dataTask, codeTask)
            phase = .loaded(data)
            affiliateCode = code
        } catch {
            phase = .error("Couldn't load friends. Try again.")
        }
    }

    // MARK: - Requests

    func acceptRequest(_ request: FriendRequest) {
        guard case .loaded(var data) = phase else { return }
        // Optimistic remove
        data.requests.removeAll { $0.id == request.id }
        phase = .loaded(data)

        Task {
            do {
                try await repository.acceptRequest(id: request.id, requesterUserID: request.requesterUserID)
                NotificationCenter.default.post(name: .apolloFeedShouldRefresh, object: nil)
                Analytics.track(.requestAccepted)
            } catch {
                // Revert: re-insert at the front
                if case .loaded(var current) = phase {
                    current.requests.insert(request, at: 0)
                    phase = .loaded(current)
                }
                toastMessage = "Couldn't accept request. Try again."
            }
        }
    }

    func declineRequest(_ request: FriendRequest) {
        guard case .loaded(var data) = phase else { return }
        data.requests.removeAll { $0.id == request.id }
        phase = .loaded(data)
        Analytics.track(.requestDeclined)

        Task {
            do {
                try await repository.declineRequest(id: request.id)
            } catch {
                // Revert
                if case .loaded(var current) = phase {
                    current.requests.insert(request, at: 0)
                    phase = .loaded(current)
                }
                toastMessage = "Couldn't decline request. Try again."
            }
        }
    }

    // MARK: - Recommended

    func addRecommended(_ user: RecommendedUser) {
        guard case .loaded(var data) = phase else { return }
        if let idx = data.recommended.firstIndex(where: { $0.id == user.id }) {
            data.recommended[idx].hasRequested = true
        }
        phase = .loaded(data)
        Analytics.track(.friendAdded, ["source": "recommended"])

        Task {
            do {
                try await repository.sendFriendRequest(to: user.id)
            } catch {
                // Revert pill back to "Add"
                if case .loaded(var current) = phase,
                   let idx = current.recommended.firstIndex(where: { $0.id == user.id }) {
                    current.recommended[idx].hasRequested = false
                    phase = .loaded(current)
                }
                toastMessage = "Couldn't send request. Try again."
            }
        }
    }

    func dismissRecommended(_ user: RecommendedUser) {
        guard case .loaded(var data) = phase else { return }
        data.recommended.removeAll { $0.id == user.id }
        phase = .loaded(data)
        Task { try? await repository.dismissRecommendation(id: user.id) }
    }

    // MARK: - Search

    /// Add from search results. Optimistically flips state to `.requestedByMe`.
    func addFromSearch(_ result: UserSearchResult) {
        if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
            searchResults[idx].state = .requestedByMe
        }
        Analytics.track(.friendAdded, ["source": "search"])

        Task {
            do {
                try await repository.sendFriendRequest(to: result.id)
            } catch {
                // Revert
                if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                    searchResults[idx].state = .none
                }
                toastMessage = "Couldn't send request. Try again."
            }
        }
    }

    /// Accept an incoming request surfaced via search results.
    func acceptFromSearch(_ result: UserSearchResult, friendshipID: UUID) {
        let fakeRequest = FriendRequest(
            id: friendshipID,
            requesterUserID: result.id,
            displayName: result.displayName,
            handle: result.handle,
            avatarURL: result.avatarURL,
            sourceLabel: "Wants to be friends"
        )
        if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
            searchResults[idx].state = .friends
        }
        Task {
            do {
                try await repository.acceptRequest(id: friendshipID, requesterUserID: result.id)
                NotificationCenter.default.post(name: .apolloFeedShouldRefresh, object: nil)
                Analytics.track(.requestAccepted)
            } catch {
                if let idx = searchResults.firstIndex(where: { $0.id == result.id }) {
                    searchResults[idx].state = .incomingRequest(friendshipID: friendshipID)
                }
                toastMessage = "Couldn't accept request. Try again."
            }
        }
        _ = fakeRequest // suppress unused warning
    }

    private func scheduleSearch() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results immediately when the field empties.
        if query.isEmpty {
            searchTask?.cancel()
            searchTask = nil
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }

        searchTask?.cancel()
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                isSearching = true
                searchError = nil
                let results = try await repository.searchUsers(query: query)
                guard !Task.isCancelled else { return }
                searchResults = results
                isSearching = false
                Analytics.track(.searchPerformed, [
                    "query_length": query.count,
                    "result_count": results.count
                ])
            } catch is CancellationError {
                // Normal debounce cancellation — do nothing.
            } catch {
                guard !Task.isCancelled else { return }
                isSearching = false
                searchError = "Search unavailable. Try again."
            }
        }
    }

    // MARK: - Invite analytics

    func trackInviteCodeCopied() {
        Analytics.track(.inviteCodeCopied)
    }

    func trackInviteCodeShared() {
        Analytics.track(.inviteCodeShared)
    }
}
