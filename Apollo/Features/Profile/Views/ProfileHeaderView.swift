//
//  ProfileHeaderView.swift
//  Apollo
//
//  Avatar + display name + handle + stats row.
//  Matches Figma node 12839-3146: 80pt avatar circle on the left,
//  name/handle/stats stacked to the right.
//

import SwiftUI
import Kingfisher

struct ProfileHeaderView: View {
    var user: ProfileUser

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            avatarView
            VStack(alignment: .leading, spacing: 8) {
                nameStack
                statsRow
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    // MARK: Avatar

    private var avatarView: some View {
        Group {
            if let url = user.avatarURL {
                KFImage(url)
                    .resizable()
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.apolloBackground, lineWidth: 2))
        .accessibilityLabel("\(user.displayName)'s avatar")
    }

    // MARK: Name + handle

    private var nameStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(user.displayName)
                .font(.sfPro(24, weight: .regular))
                .foregroundStyle(Color.apolloPrimaryText)
                .lineLimit(1)
            Text("@\(user.handle)")
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloWinsLabel)
                .lineLimit(1)
        }
    }

    // MARK: Stats — "47 Wins · 14d Streak · 12 Friends"

    private var statsRow: some View {
        HStack(spacing: 22) {
            statItem(value: "\(user.totalWins)", label: "Wins")
            statItem(value: "\(user.streak)d", label: "Streak")
            statItem(value: "\(user.friendCount)", label: "Friends")
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(user.totalWins) wins, \(user.streak) day streak, \(user.friendCount) friends")
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.sfPro(16, weight: .semibold))
                .foregroundStyle(Color.apolloCaption)
            Text(label)
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloWinsLabel)
        }
    }
}

// MARK: - Skeleton

struct ProfileHeaderSkeletonView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Circle()
                .fill(Color.apolloSkeleton)
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 120, height: 20)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 80, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 160, height: 14)
            }
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileHeaderView(user: ProfileUser(
            id: UUID(),
            displayName: "Jayden Betts",
            handle: "jaydenbetts",
            avatarURL: nil,
            bannerPhotoURLs: [],
            totalWins: 47,
            streak: 14,
            friendCount: 12,
            isCurrentUser: true
        ))
        ProfileHeaderSkeletonView()
    }
    .padding(.vertical, 16)
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
