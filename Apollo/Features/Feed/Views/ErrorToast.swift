//
//  ErrorToast.swift
//  Apollo
//

import SwiftUI

struct ErrorToast: View {
    var message: String
    var actionLabel: String?
    var onAction: (() -> Void)?
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.sfPro(13))
                .foregroundStyle(Color.apolloErrorToastBody)
            Spacer(minLength: 0)
            if let actionLabel, let onAction {
                Button(actionLabel) {
                    onAction()
                }
                .font(.sfPro(13, weight: .medium))
                .foregroundStyle(Color.apolloText)
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.apolloErrorToastBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.apolloMuted, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
        .task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            onDismiss()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        ErrorToast(
            message: "Couldn't load your feed.",
            actionLabel: "Try again",
            onAction: {},
            onDismiss: {}
        )
        Spacer()
    }
    .background(Color.apolloBackground)
}
