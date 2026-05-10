//
//  NotificationRow.swift
//  Apollo
//
//  A single row in the in-app Notification Center.
//
//  Spec (PRD §4):
//   • Height: 56pt
//   • Avatar: 36pt circle, left 16pt
//   • Unread dot: 6pt white, 8pt left of avatar
//   • Copy: SF Pro Regular 13pt #888888, right of avatar (10pt gap), 2-line max
//   • Timestamp: SF Pro Regular 11pt #252525, below copy
//   • Background (unread): #0e0e0e
//   • Background (read):   #080808
//

import Kingfisher
import SwiftUI

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    private static let unreadBackground = Color(red: 0x0e / 255, green: 0x0e / 255, blue: 0x0e / 255)
    private static let copyColor        = Color(red: 0x88 / 255, green: 0x88 / 255, blue: 0x88 / 255)
    private static let timestampColor   = Color(red: 0x25 / 255, green: 0x25 / 255, blue: 0x25 / 255)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Unread dot (6pt) — sits 8pt left of avatar.
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .opacity(notification.isRead ? 0 : 1)
                    .accessibilityLabel(notification.isRead ? "" : "Unread notification")
                    .padding(.leading, 8)
                    .padding(.trailing, 2)

                // Avatar (36pt).
                avatarView
                    .padding(.leading, 6)

                // Copy + timestamp.
                VStack(alignment: .leading, spacing: 2) {
                    Text(notification.copy)
                        .font(.sfPro(13))
                        .foregroundStyle(Self.copyColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(relativeTimestamp)
                        .font(.sfPro(11))
                        .foregroundStyle(Self.timestampColor)
                }
                .padding(.leading, 10)
                .padding(.trailing, 16)

                Spacer(minLength: 0)
            }
            .frame(height: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(notification.isRead ? Color.apolloBackground : Self.unreadBackground)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(notification.copy)
        .accessibilityHint("Tap to open")
    }

    @ViewBuilder
    private var avatarView: some View {
        Group {
            if let url = notification.actor?.avatarURL {
                KFImage(url)
                    .resizable()
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private var relativeTimestamp: String {
        let diff = Date().timeIntervalSince(notification.timestamp)
        if diff < 60            { return "just now" }
        if diff < 3_600         { return "\(Int(diff / 60))m" }
        if diff < 86_400        { return "\(Int(diff / 3_600))h" }
        if diff < 7 * 86_400    { return "\(Int(diff / 86_400))d" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: notification.timestamp)
    }
}
