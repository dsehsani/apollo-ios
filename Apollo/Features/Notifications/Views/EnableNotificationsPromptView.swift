//
//  EnableNotificationsPromptView.swift
//  Apollo
//
//  Pre-permission prompt shown after the user posts their first ever win.
//  Mirrors Apple's best-practice of a custom prompt before the system dialog.
//
//  PRD §5 copy:
//   Title:  "Stay in the loop."
//   Body:   "Get notified when friends post wins, react to yours, and when your streak is about to break."
//   CTA:    "Turn on notifications" (white pill)
//   Skip:   "Maybe later" (text link below)
//

import SwiftUI

struct EnableNotificationsPromptView: View {
    @EnvironmentObject private var notificationsService: NotificationsService
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drag pill.
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.apolloStroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)

            Spacer()

            // Bell icon.
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.apolloPrimaryText)
                .padding(.bottom, 24)

            // Title.
            Text("Stay in the loop.")
                .font(.goudyItalic(28))
                .foregroundStyle(Color.apolloPrimaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)

            // Body.
            Text("Get notified when friends post wins, react to yours, and when your streak is about to break.")
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloCaption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // CTA button.
            Button {
                Task {
                    UserDefaults.standard.set(true, forKey: "apollo.hasShownPushPrompt")
                    _ = await notificationsService.requestAuthorization(context: .postFirstWin)
                    onDismiss()
                }
            } label: {
                Text("Turn on notifications")
                    .font(.sfPro(16, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .padding(.horizontal, 24)
            }

            // Maybe later.
            Button {
                UserDefaults.standard.set(true, forKey: "apollo.hasShownPushPrompt")
                onDismiss()
            } label: {
                Text("Maybe later")
                    .font(.sfPro(14))
                    .foregroundStyle(Color.apolloCaption)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
            }

            Spacer(minLength: 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
    }
}

#Preview {
    EnableNotificationsPromptView(onDismiss: {})
        .environmentObject(NotificationsService())
        .preferredColorScheme(.dark)
}
