//
//  ReactionsBreakdownRow.swift
//  Apollo
//

import SwiftUI
import Kingfisher

struct ReactionsBreakdownRow: View {
    var reaction: Reaction

    var body: some View {
        HStack(spacing: 10) {
            avatar
            userInfo
            Spacer(minLength: 8)
            Text(reaction.emoji)
                .font(.system(size: 16))
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reaction.username) reacted with \(reaction.emoji)")
    }

    private var avatar: some View {
        Group {
            if let url = reaction.avatarURL {
                KFImage(url)
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: 30, height: 30)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.apolloAvatarBorder, lineWidth: 1))
    }

    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(reaction.username)
                .font(.sfPro(12, weight: .medium))
                .foregroundStyle(Color(red: 0x88/255, green: 0x88/255, blue: 0x88/255))
                .lineLimit(1)
            Text("@\(reaction.username)")
                .font(.sfPro(10))
                .foregroundStyle(Color.apolloMuted)
                .lineLimit(1)
        }
    }
}
