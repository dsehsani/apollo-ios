//
//  EmptyFeedView.swift
//  Apollo
//

import SwiftUI

struct EmptyFeedView: View {
    var onWinTapped: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Text("Be the first to post today.")
                .font(.goudyItalic(18))
                .foregroundStyle(Color.apolloText)
                .multilineTextAlignment(.center)
            Button(action: onWinTapped) {
                Text("Win")
                    .font(.sfPro(15, weight: .medium))
                    .foregroundStyle(Color.apolloBackground)
                    .frame(width: 120, height: 44)
                    .background(Color.apolloText, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Win — open camera")
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyFeedView(onWinTapped: {})
        .background(Color.apolloBackground)
}
