//
//  RecommendedFriendRow.swift
//  Apollo
//
//  Recommended user row. Matches Figma nodes 12839:3097–3144.
//  Tapping Add optimistically flips to "Requested" (muted) + hides the X.
//

import SwiftUI

struct RecommendedFriendRow: View {
    let user: RecommendedUser
    var onAdd: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            FriendAvatarView(url: user.avatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.sfPro(15, weight: .semibold))
                    .foregroundStyle(Color.apolloUsername)
                    .lineLimit(1)
                Text(user.handle)
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTabInactive)
                    .lineLimit(1)
                Text(user.subLabel)
                    .font(.sfPro(11))
                    .foregroundStyle(Color.apolloWinsValue)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 18) {
                Button(action: onAdd) {
                    Text(user.hasRequested ? "Requested" : "Add")
                        .font(.sfPro(14, weight: .medium))
                        .foregroundStyle(user.hasRequested ? Color.apolloTabInactive : Color.apolloPrimaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.apolloFriendsPillFill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(user.hasRequested)
                .accessibilityLabel(user.hasRequested ? "Request sent to \(user.displayName)" : "Add \(user.displayName)")

                if !user.hasRequested {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.apolloIconStroke)
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss \(user.displayName)")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 0) {
        RecommendedFriendRow(
            user: RecommendedUser(id: UUID(), displayName: "Angel Gomez", handle: "angel_gomez", avatarURL: nil, subLabel: "7 Mutuals"),
            onAdd: {},
            onDismiss: {}
        )
        RecommendedFriendRow(
            user: RecommendedUser(id: UUID(), displayName: "Marge Kellogg", handle: "grandma_vibes", avatarURL: nil, subLabel: "10 Mutuals", hasRequested: true),
            onAdd: {},
            onDismiss: {}
        )
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
