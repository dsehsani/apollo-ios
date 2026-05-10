//
//  FriendRequestRow.swift
//  Apollo
//
//  A single pending friend request row. Matches Figma node 12839:3082.
//  Accept and X both remove the row with a 0.3s fade.
//

import SwiftUI

struct FriendRequestRow: View {
    let request: FriendRequest
    var onAccept: () -> Void
    var onDecline: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            FriendAvatarView(url: request.avatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName)
                    .font(.sfPro(15, weight: .semibold))
                    .foregroundStyle(Color.apolloUsername)
                    .lineLimit(1)
                Text(request.handle)
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTabInactive)
                    .lineLimit(1)
                Text(request.sourceLabel)
                    .font(.sfPro(11))
                    .foregroundStyle(Color.apolloWinsValue)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 18) {
                Button(action: onAccept) {
                    Text("Accept")
                        .font(.sfPro(14, weight: .medium))
                        .foregroundStyle(Color.apolloFriendsAcceptText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.apolloPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Accept \(request.displayName)'s friend request")

                Button(action: onDecline) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.apolloIconStroke)
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decline \(request.displayName)'s request")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    FriendRequestRow(
        request: FriendRequest(
            id: UUID(),
            requesterUserID: UUID(),
            displayName: "Jayden Betts",
            handle: "angryjayden",
            avatarURL: nil,
            sourceLabel: "In your contacts"
        ),
        onAccept: {},
        onDecline: {}
    )
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
