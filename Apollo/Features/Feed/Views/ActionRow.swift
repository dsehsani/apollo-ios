//
//  ActionRow.swift
//  Apollo
//

import SwiftUI

struct ActionRow: View {
    var onCommentTap: () -> Void
    var onReactionTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            iconButton(
                imageName: "IconMessageCirclePlus",
                accessibility: "Comment",
                action: onCommentTap
            )
            iconButton(
                imageName: "IconSmilePlus",
                accessibility: "React",
                action: onReactionTap
            )
        }
    }

    @ViewBuilder
    private func iconButton(
        imageName: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .foregroundStyle(Color.apolloPrimaryText)
                .frame(width: 24, height: 24)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

#Preview {
    ActionRow(onCommentTap: {}, onReactionTap: {})
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
