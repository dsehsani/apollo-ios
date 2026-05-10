//
//  InviteContactRow.swift
//  Apollo
//
//  Contact row for people not yet on Apollo. Matches Figma nodes 12839:2992–3033.
//  Tap Invite opens the iOS Share Sheet with a pre-built message (no affiliate code yet).
//

import SwiftUI

struct InviteContactRow: View {
    let contact: InviteContact

    private var shareMessage: String {
        "Join me on Apollo — the app where I track my daily wins. Download it here: https://apollo.app"
    }

    var body: some View {
        HStack(spacing: 6) {
            FriendAvatarView(url: contact.avatarURL)

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.displayName)
                    .font(.sfPro(15, weight: .semibold))
                    .foregroundStyle(Color.apolloUsername)
                    .lineLimit(1)
                Text(contact.handle)
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTabInactive)
                    .lineLimit(1)
                Text("Not here yet")
                    .font(.sfPro(11))
                    .foregroundStyle(Color.apolloWinsValue)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            ShareLink(item: shareMessage) {
                Text("Invite")
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.apolloFriendsPillFill)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Invite \(contact.displayName) to Apollo")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    InviteContactRow(
        contact: InviteContact(id: UUID(), displayName: "Yao Ming", handle: "yaoming89", avatarURL: nil)
    )
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
