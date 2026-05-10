//
//  PostHeader.swift
//  Apollo
//

import SwiftUI
import Kingfisher

struct PostHeader: View {
    var post: Post
    var onAvatarTap: () -> Void
    var onUsernameTap: () -> Void
    // The `···` button was removed in the Figma restyle, but we keep this
    // callback so PostCard's call site remains untouched. Future agents may
    // re-wire it (e.g. via long-press on the header) without touching the API.
    var onMoreTap: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: onAvatarTap) {
                avatar
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(post.user.username)'s profile photo")

            VStack(alignment: .leading, spacing: 2) {
                Button(action: onUsernameTap) {
                    Text(post.user.username)
                        .font(.sfPro(14))
                        .tracking(-0.28)
                        .foregroundStyle(Color.apolloUsername)
                }
                .buttonStyle(.plain)

                Text(metaLine)
                    .font(.sfPro(12))
                    .tracking(-0.24)
                    .foregroundStyle(Color.apolloTimeStreak)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(post.winsCount)")
                    .font(.sfPro(20, weight: .semibold))
                    .foregroundStyle(Color.apolloWinsValue)
                Text("Wins")
                    .font(.sfPro(10))
                    .foregroundStyle(Color.apolloWinsLabel)
            }
        }
        .padding(.leading, ApolloSpacing.postHeaderHorizontal)
        .padding(.trailing, 16)
        .frame(height: 36)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = post.user.avatarURL {
            KFImage(url)
                .resizable()
                .placeholder { Color.apolloSkeleton }
                .scaledToFill()
                .frame(width: 33, height: 33)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(Color.apolloSkeleton)
                .frame(width: 33, height: 33)
        }
    }

    private var metaLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let timeString = formatter.string(from: post.createdAt)
        return "\(timeString)・\(post.user.streak)d Streak"
    }
}

#Preview {
    PostHeader(
        post: Post(
            id: UUID(),
            user: PostUser(id: UUID(), username: "darius", avatarURL: nil, streak: 14),
            createdAt: .now,
            caption: "",
            photoCount: 0,
            mainPhotoURL: nil,
            towerPhotos: [],
            winsCount: 3,
            reactions: [],
            commentCount: 0,
            currentUserReaction: nil
        ),
        onAvatarTap: {},
        onUsernameTap: {},
        onMoreTap: {}
    )
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
