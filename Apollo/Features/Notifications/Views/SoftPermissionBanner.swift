//
//  SoftPermissionBanner.swift
//  Apollo
//
//  Shown in FriendsView when push permission is denied (PRD §5):
//  "Turn on notifications to know when friends post." → "Settings" link.
//

import SwiftUI

struct SoftPermissionBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.apolloCaption)

            Text("Turn on notifications to know when friends post.")
                .font(.sfPro(13))
                .foregroundStyle(Color.apolloCaption)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)

            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.sfPro(13, weight: .medium))
            .foregroundStyle(Color.apolloPrimaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.apolloSurface)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Notifications are off. Turn on notifications to know when friends post.")
        .accessibilityHint("Tap Settings to open system settings.")
    }
}

#Preview {
    SoftPermissionBanner()
        .preferredColorScheme(.dark)
}
