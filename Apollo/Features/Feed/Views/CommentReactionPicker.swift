//
//  CommentReactionPicker.swift
//  Apollo
//
//  Mirrors ReactionPicker but with the comment emoji set (❤️ 👅 😂 +).
//  Sits as an overlay above the smiley button on each CommentRow.
//

import SwiftUI

struct CommentReactionPicker: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Raw emoji for current user's reaction on this comment, if any.
    var currentReaction: String?
    var onSelect: (String) -> Void
    var onPlusTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CommentEmoji.pickerOrder, id: \.self) { emoji in
                Button {
                    onSelect(emoji.rawValue)
                } label: {
                    Text(emoji.rawValue)
                        .font(.system(size: 20))
                        .padding(.horizontal, 2)
                        .opacity(currentReaction == emoji.rawValue ? 1.0 : 0.95)
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
            .accessibilityLabel("More emojis")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.apolloSurface))
        .overlay(Capsule().stroke(Color.apolloBorder, lineWidth: 0.5))
        .transition(reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity))
    }

    private func accessibilityLabel(for emoji: CommentEmoji) -> String {
        switch emoji {
        case .heart:  return "React with heart"
        case .tongue: return "React with tongue"
        case .joy:    return "React with joy"
        }
    }
}

#Preview {
    CommentReactionPicker(currentReaction: nil, onSelect: { _ in }, onPlusTap: {})
        .padding()
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
