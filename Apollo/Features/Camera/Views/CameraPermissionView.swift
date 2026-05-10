//
//  CameraPermissionView.swift
//  Apollo
//
//  Shown when the user has denied camera access. Deep-links to iOS Settings.
//  PRD §3C and §14.
//

import SwiftUI

struct CameraPermissionView: View {
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            HStack {
                CameraIconButton(
                    asset: "IconChevronDown",
                    tint: .apolloText,
                    accessibilityLabel: "Close camera",
                    action: onClose
                )
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            VStack(spacing: 24) {
                Spacer()
                Text("Apollo needs camera access to document your wins.")
                    .font(.sfPro(16))
                    .foregroundStyle(Color.apolloErrorToastBody)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onOpenSettings) {
                    Text("Open Settings")
                        .font(.sfPro(15, weight: .medium))
                        .foregroundStyle(Color.apolloBackground)
                        .frame(width: 160, height: 44)
                        .background(Color.apolloText, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open Settings")
                Spacer()
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    CameraPermissionView(onClose: {}, onOpenSettings: {})
        .preferredColorScheme(.dark)
}
