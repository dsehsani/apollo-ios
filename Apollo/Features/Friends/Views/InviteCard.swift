//
//  InviteCard.swift
//  Apollo
//
//  Invite card shown above "Invite Friends" section. Displays the user's
//  affiliate code with a copy button (haptic feedback) and a share pill
//  that opens the iOS Share Sheet with a pre-built invite message.
//

import SwiftUI
import UIKit

struct InviteCard: View {
    let affiliateCode: String?
    var onCopy: () -> Void
    var onShare: () -> Void

    private var shareMessage: String {
        if let code = affiliateCode {
            return "Join me on Apollo — the app where I track my daily wins. Use my code \(code) for 10% off Pro."
        }
        return "Join me on Apollo — the app where I track my daily wins."
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("YOUR CODE")
                    .font(.sfPro(10, weight: .semibold))
                    .foregroundStyle(Color.apolloTabInactive)
                    .tracking(1.2)
                Text(affiliateCode ?? "—")
                    .font(.sfPro(20, weight: .semibold))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .redacted(reason: affiliateCode == nil ? .placeholder : [])
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                // Copy button
                Button {
                    if let code = affiliateCode {
                        UIPasteboard.general.string = code
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onCopy()
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(Color.apolloPrimaryText)
                        .frame(width: 36, height: 36)
                        .background(Color.apolloFriendsPillFill)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(affiliateCode == nil)
                .accessibilityLabel("Copy invite code")

                // Share pill
                ShareLink(item: shareMessage) {
                    Text("Share")
                        .font(.sfPro(14, weight: .medium))
                        .foregroundStyle(Color.apolloPrimaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.apolloFriendsPillFill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { onShare() })
                .disabled(affiliateCode == nil)
                .accessibilityLabel("Share invite code")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 0) {
        InviteCard(affiliateCode: "APOLLO10", onCopy: {}, onShare: {})
        InviteCard(affiliateCode: nil, onCopy: {}, onShare: {})
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
