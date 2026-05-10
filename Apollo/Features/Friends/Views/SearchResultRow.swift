//
//  SearchResultRow.swift
//  Apollo
//
//  Search result row. Same visual layout as RecommendedFriendRow.
//  The action pill adapts to the user's current FriendshipState.
//

import SwiftUI

struct SearchResultRow: View {
    let result: UserSearchResult
    var onAdd: () -> Void
    var onAccept: (_ friendshipID: UUID) -> Void

    var body: some View {
        HStack(spacing: 6) {
            FriendAvatarView(url: result.avatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.displayName)
                    .font(.sfPro(15, weight: .semibold))
                    .foregroundStyle(Color.apolloUsername)
                    .lineLimit(1)
                Text(result.handle)
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTabInactive)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            pillButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var pillButton: some View {
        switch result.state {
        case .none:
            Button(action: onAdd) {
                Text("Add")
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.apolloFriendsPillFill)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add \(result.displayName)")

        case .requestedByMe:
            Text("Requested")
                .font(.sfPro(14, weight: .medium))
                .foregroundStyle(Color.apolloTabInactive)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.apolloFriendsPillFill)
                .clipShape(Capsule())
                .accessibilityLabel("Request sent to \(result.displayName)")

        case .incomingRequest(let fid):
            Button { onAccept(fid) } label: {
                Text("Accept")
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloFriendsAcceptText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.apolloPrimaryText)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept \(result.displayName)'s friend request")

        case .friends:
            Text("Friends")
                .font(.sfPro(14, weight: .medium))
                .foregroundStyle(Color.apolloTabInactive)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.apolloFriendsPillFill)
                .clipShape(Capsule())
                .accessibilityLabel("Already friends with \(result.displayName)")
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        SearchResultRow(
            result: UserSearchResult(id: UUID(), displayName: "Angel Gomez", handle: "angel_gomez", avatarURL: nil, state: .none),
            onAdd: {},
            onAccept: { _ in }
        )
        SearchResultRow(
            result: UserSearchResult(id: UUID(), displayName: "Marge Kellogg", handle: "grandma_vibes", avatarURL: nil, state: .requestedByMe),
            onAdd: {},
            onAccept: { _ in }
        )
        SearchResultRow(
            result: UserSearchResult(id: UUID(), displayName: "Jayden Betts", handle: "angryjayden", avatarURL: nil, state: .incomingRequest(friendshipID: UUID())),
            onAdd: {},
            onAccept: { _ in }
        )
        SearchResultRow(
            result: UserSearchResult(id: UUID(), displayName: "Yao Ming", handle: "yaoming89", avatarURL: nil, state: .friends),
            onAdd: {},
            onAccept: { _ in }
        )
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
