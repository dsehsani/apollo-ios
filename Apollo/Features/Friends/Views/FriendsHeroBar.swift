//
//  FriendsHeroBar.swift
//  Apollo
//
//  "Connect" title + QR icon button. Matches Figma node 12839:2974.
//

import SwiftUI

struct FriendsHeroBar: View {
    var onQRTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Connect")
                .font(.goudyRegular(36))
                .foregroundStyle(Color.apolloPrimaryText)

            Spacer()

            Button(action: onQRTap) {
                Image(systemName: "qrcode")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.apolloFriendsQRButton)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show QR code")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    FriendsHeroBar()
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
