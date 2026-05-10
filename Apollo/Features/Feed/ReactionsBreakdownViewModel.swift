//
//  ReactionsBreakdownViewModel.swift
//  Apollo
//

import Foundation
import Observation

enum BreakdownFilter: Hashable, Sendable {
    case all
    /// A standard post-picker emoji ("❤️", "🔥", "👑").
    case known(String)
    /// Any emoji outside the standard post-picker set.
    case custom
}

@Observable
@MainActor
final class ReactionsBreakdownViewModel {

    enum Phase: Equatable {
        case loading
        case loaded
        case error
    }

    private let repository: FeedRepository
    private let postID: UUID

    var phase: Phase = .loading
    var reactions: [Reaction] = []
    var selectedFilter: BreakdownFilter = .all
    var errorMessage: String?

    init(postID: UUID, repository: FeedRepository) {
        self.postID = postID
        self.repository = repository
    }

    func load() async {
        phase = .loading
        errorMessage = nil
        do {
            let fetched = try await repository.fetchReactionsBreakdown(postID: postID)
            reactions = fetched.sorted { $0.createdAt > $1.createdAt }
            phase = .loaded
        } catch {
            phase = .error
            errorMessage = "Couldn't load reactions."
        }
    }

    func select(filter: BreakdownFilter) {
        selectedFilter = filter
        Analytics.track(.breakdownFiltered, ["filter": labelFor(filter)])
    }

    var filteredReactions: [Reaction] {
        switch selectedFilter {
        case .all:
            return reactions
        case .known(let emoji):
            return reactions.filter { $0.emoji == emoji }
        case .custom:
            return reactions.filter { !ReactionEmoji.postPickerSet.contains($0.emoji) }
        }
    }

    /// Counts per emoji across all reactions.
    var counts: [String: Int] {
        Dictionary(grouping: reactions, by: { $0.emoji }).mapValues { $0.count }
    }

    /// Ordered filter tabs to display: All, then each standard emoji present, then Custom if any.
    var availableFilters: [BreakdownFilter] {
        var filters: [BreakdownFilter] = [.all]
        for emoji in ReactionEmoji.postPickerOrder.map(\.rawValue) {
            if (counts[emoji] ?? 0) > 0 {
                filters.append(.known(emoji))
            }
        }
        let hasCustom = reactions.contains { !ReactionEmoji.postPickerSet.contains($0.emoji) }
        if hasCustom {
            filters.append(.custom)
        }
        return filters
    }

    var totalCount: Int { reactions.count }

    private func labelFor(_ filter: BreakdownFilter) -> String {
        switch filter {
        case .all:           return "all"
        case .known(let e):  return e
        case .custom:        return "custom"
        }
    }
}
