//
//  ReactionPicker.swift
//  Apollo
//

import SwiftUI

struct ReactionPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var currentReaction: ReactionEmoji?
    var onSelect: (ReactionEmoji) -> Void
    var onPlusTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReactionEmoji.pickerOrder, id: \.self) { emoji in
                Button {
                    onSelect(emoji)
                } label: {
                    Text(emoji.rawValue)
                        .font(.system(size: 20))
                        .padding(.horizontal, 2)
                        .opacity(currentReaction == emoji ? 1.0 : 0.95)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: emoji))
            }
            Button(action: onPlusTap) {
                Text("+")
                    .font(.sfPro(18, weight: .regular))
                    .foregroundStyle(Color.apolloText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More reactions")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(Color.apolloSurface)
        )
        .overlay(
            Capsule().stroke(Color.apolloBorder, lineWidth: 0.5)
        )
        .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity))
    }

    private func accessibilityLabel(for emoji: ReactionEmoji) -> String {
        switch emoji {
        case .heart: return "React with heart"
        case .fire: return "React with fire"
        case .crown: return "React with crown"
        }
    }
}

#Preview {
    ReactionPicker(currentReaction: nil, onSelect: { _ in }, onPlusTap: {})
        .padding()
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
