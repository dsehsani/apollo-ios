//
//  TodaysWinsSection.swift
//  Apollo
//
//  "TODAY'S WINS" section on the Profile screen (PRD §06 §4F).
//  Reuses PhotoArea, PhotoTower, and ReactionsLine from the Feed feature.
//

import SwiftUI

struct TodaysWinsSection: View {
    var post: ProfilePost
    var isCurrentUser: Bool
    var featuredPhotoIndex: Int
    var onFeaturedPhotoTap: () -> Void
    var onTowerPhotoTap: (Int) -> Void
    var onMoreTap: () -> Void
    var onReactionsLineTap: () -> Void
    var onCommentTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader
                .padding(.top, 24)

            PhotoArea(
                post: bridgedPost,
                featuredIndex: featuredPhotoIndex,
                onFeaturedPhotoTap: onFeaturedPhotoTap,
                onTowerPhotoTap: onTowerPhotoTap
            )
            .padding(.top, 8)

            captionBlock
                .padding(.top, 10)
                .padding(.horizontal, 16)

            if !post.reactions.isEmpty {
                ReactionsLine(reactions: post.reactions, onTap: onReactionsLineTap)
                    .padding(.top, 16)
            }
        }
    }

    // MARK: Section header

    private var sectionHeader: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("TODAY'S WINS")
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloTimeStreak)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                VStack(alignment: .trailing, spacing: 0) {
                    Text("\(post.winsCount)")
                        .font(.sfPro(20, weight: .semibold))
                        .foregroundStyle(Color.apolloWinsValue)
                    Text("Wins")
                        .font(.sfPro(10))
                        .foregroundStyle(Color.apolloWinsLabel)
                }

                if isCurrentUser {
                    moreMenu
                }
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's wins. \(post.winsCount) wins total.")
    }

    // MARK: ··· menu

    private var moreMenu: some View {
        Menu {
            Button("Edit post", action: {})
            Button("Share strip", action: {})
            Button(role: .destructive) {} label: { Text("Delete post") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundStyle(Color.apolloIconStroke)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Post options")
    }

    // MARK: Caption

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(post.caption)
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloCaption)
                .lineLimit(2)

            if post.caption.count > 60 {
                Text("tap to see more")
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloWinsLabel)
            }
        }
    }

    // MARK: Bridge to Post for PhotoArea reuse

    private var bridgedPost: Post {
        Post(
            id: post.id,
            user: PostUser(id: UUID(), username: "", avatarURL: nil, streak: 0),
            createdAt: .now,
            caption: post.caption,
            photoCount: 1 + post.towerPhotos.count,
            mainPhotoURL: post.mainPhotoURL,
            towerPhotos: post.towerPhotos,
            winsCount: post.winsCount,
            reactions: post.reactions,
            commentCount: post.commentCount,
            currentUserReaction: nil
        )
    }
}

// MARK: - Empty state

struct TodaysWinsEmptyView: View {
    var onCameraTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Post your first win today.")
                .font(.goudyItalic(16))
                .foregroundStyle(Color(red: 0x33 / 255, green: 0x33 / 255, blue: 0x33 / 255))
                .multilineTextAlignment(.center)

            Button(action: onCameraTap) {
                HStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 14))
                    Text("Shoot a win")
                        .font(.sfPro(14))
                }
                .foregroundStyle(Color.apolloText)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.apolloSurface)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
    }
}
