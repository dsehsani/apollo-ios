//
//  GroupedReactionsLine.swift
//  Apollo
//
//  Compact reaction strip for PostCard. Shows each emoji with its count,
//  sorted by count descending. The emoji matching the current user's reaction
//  is highlighted in the primary text colour; others use the muted style.
//

import SwiftUI

struct GroupedReactionsLine: View {
    /// Ordered (emoji, count) pairs produced by Post.orderedReactionCounts.
    var pairs: [(emoji: String, count: Int)]
    /// Raw emoji string for the current user's active reaction, or nil.
    var currentUserReaction: String?
    var onTap: () -> Void

    var body: some View {
        if pairs.isEmpty {
            EmptyView()
        } else {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    ForEach(pairs, id: \.emoji) { pair in
                        reactionChip(pair)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.leading, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    @ViewBuilder
    private func reactionChip(_ pair: (emoji: String, count: Int)) -> some View {
        let isOwn = pair.emoji == currentUserReaction
        HStack(spacing: 3) {
            Text(pair.emoji)
                .font(.system(size: 14))
            Text("\(pair.count)")
                .font(.sfPro(12, weight: isOwn ? .semibold : .regular))
                .foregroundStyle(
                    isOwn ? Color.apolloPrimaryText : Color.apolloReactorMuted
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(pair.emoji) \(pair.count)\(isOwn ? ", your reaction" : "")")
    }

    private var accessibilityLabel: String {
        let parts = pairs.map { "\($0.emoji) \($0.count)" }
        let joined = parts.joined(separator: ", ")
        if let own = currentUserReaction {
            return "Reactions: \(joined). You reacted with \(own)."
        }
        return "Reactions: \(joined)."
    }
}

#Preview {
    let pairs: [(emoji: String, count: Int)] = [
        (emoji: "❤️", count: 12),
        (emoji: "👑", count: 4),
        (emoji: "😂", count: 2),
    ]
    GroupedReactionsLine(pairs: pairs, currentUserReaction: "❤️", onTap: {})
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
