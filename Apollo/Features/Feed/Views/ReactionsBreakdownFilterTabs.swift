//
//  ReactionsBreakdownFilterTabs.swift
//  Apollo
//

import SwiftUI

struct ReactionsBreakdownFilterTabs: View {
    var filters: [BreakdownFilter]
    var counts: [String: Int]
    var totalCount: Int
    var selected: BreakdownFilter
    var onSelect: (BreakdownFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(filters, id: \.self) { filter in
                    pill(for: filter)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func pill(for filter: BreakdownFilter) -> some View {
        let isActive = (filter == selected)
        Button {
            onSelect(filter)
        } label: {
            Text(pillLabel(for: filter))
                .font(.sfPro(11))
                .foregroundStyle(isActive ? Color.apolloPrimaryText : Color.apolloReactorMuted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(isActive ? Color.apolloBorder : Color.clear)
                )
                .overlay(
                    Capsule().stroke(Color.apolloBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel(for: filter))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func pillLabel(for filter: BreakdownFilter) -> String {
        switch filter {
        case .all:
            return "All \(totalCount)"
        case .known(let emoji):
            let count = counts[emoji] ?? 0
            return "\(emoji) \(count)"
        case .custom:
            let customCount = counts.filter { !ReactionEmoji.postPickerSet.contains($0.key) }.values.reduce(0, +)
            return "Other \(customCount)"
        }
    }

    private func accessibilityLabel(for filter: BreakdownFilter) -> String {
        switch filter {
        case .all:
            return "\(totalCount) total reactions"
        case .known(let emoji):
            let count = counts[emoji] ?? 0
            return "\(emoji), \(count) reactions"
        case .custom:
            let customCount = counts.filter { !ReactionEmoji.postPickerSet.contains($0.key) }.values.reduce(0, +)
            return "Other reactions, \(customCount)"
        }
    }
}
