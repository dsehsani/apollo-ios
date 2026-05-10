//
//  ReactionsLine.swift
//  Apollo
//

import SwiftUI
import Kingfisher

struct ReactionsLine: View {
    var reactions: [Reaction]
    var onTap: () -> Void

    private var firstReactor: Reaction? { reactions.first }
    private var othersCount: Int { max(0, reactions.count - 1) }

    private var attributedReactorText: AttributedString {
        guard let first = firstReactor else { return AttributedString() }
        var name = AttributedString(first.username)
        name.foregroundColor = Color.apolloReactor

        let othersString: String
        switch othersCount {
        case 0:
            othersString = " reacted"
        case 1:
            othersString = " & 1 other reacted"
        default:
            othersString = " & \(othersCount) others reacted"
        }

        var trailing = AttributedString(othersString)
        trailing.foregroundColor = Color.apolloReactorMuted

        var combined = AttributedString()
        combined.append(name)
        combined.append(trailing)
        return combined
    }

    var body: some View {
        if reactions.isEmpty {
            EmptyView()
        } else {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 9) {
                    avatarStack
                    Text(attributedReactorText)
                        .font(.sfPro(13))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .frame(height: 16)
                .padding(.leading, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }

    private var avatarStack: some View {
        HStack(spacing: -2) {
            ForEach(Array(reactions.prefix(3).enumerated()), id: \.element.id) { _, reaction in
                avatar(for: reaction)
            }
        }
    }

    @ViewBuilder
    private func avatar(for reaction: Reaction) -> some View {
        Group {
            if let url = reaction.avatarURL {
                KFImage(url)
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: 16, height: 16)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.apolloAvatarBorder, lineWidth: 1))
        .opacity(0.8)
    }

    private var accessibilityLabel: String {
        let first = firstReactor?.username ?? ""
        return "\(reactions.count) people reacted, including \(first)"
    }
}

#Preview {
    let r = [
        Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "jayden", avatarURL: nil, emoji: "❤️", createdAt: .now),
        Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "rildy", avatarURL: nil, emoji: "🔥", createdAt: .now),
        Reaction(id: UUID(), postID: UUID(), userID: UUID(), username: "mira", avatarURL: nil, emoji: "👑", createdAt: .now),
    ]
    ReactionsLine(reactions: r, onTap: {})
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
