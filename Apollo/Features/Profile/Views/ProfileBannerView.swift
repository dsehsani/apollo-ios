//
//  ProfileBannerView.swift
//  Apollo
//
//  141pt-tall full-width banner that shows a mosaic strip of win photos.
//  Matches the Figma design (node 12839-3146): tiles arranged in repeating
//  groups of [tall single | two stacked halves], scrolling horizontally.
//
//  Own profile: tapping opens the banner-edit action sheet (v1 placeholder).
//  Friend profile: no action.
//  Empty (no photos): pure #080808, no placeholder image.
//

import SwiftUI
import Kingfisher

struct ProfileBannerView: View {
    var photoURLs: [URL]
    var isCurrentUser: Bool
    var onTap: (() -> Void)?

    private let bannerHeight: CGFloat = 141
    private let tileCornerRadius: CGFloat = 3
    private let tileGap: CGFloat = 3

    var body: some View {
        Group {
            if photoURLs.isEmpty {
                Color.apolloBackground
            } else {
                mosaicStrip
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: bannerHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isCurrentUser else { return }
            onTap?()
        }
        .accessibilityLabel(isCurrentUser ? "Profile banner. Double tap to edit." : "Profile banner.")
        .accessibilityAddTraits(isCurrentUser ? .isButton : [])
    }

    // Horizontal strip: groups of [tall tile | pair of stacked tiles]
    private var mosaicStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: tileGap) {
                ForEach(tileGroups.indices, id: \.self) { groupIdx in
                    let group = tileGroups[groupIdx]
                    tileGroup(group)
                }
            }
        }
        .disabled(true)
        .frame(height: bannerHeight)
    }

    // Each group contains either 1 URL (tall solo tile) or 2 URLs (stacked pair)
    private var tileGroups: [[URL]] {
        var groups: [[URL]] = []
        var i = 0
        while i < photoURLs.count {
            if (groups.count % 2 == 0) && (i + 1 < photoURLs.count) {
                // Even group → tall solo
                groups.append([photoURLs[i]])
                i += 1
            } else if i + 1 < photoURLs.count {
                // Odd group → stacked pair
                groups.append([photoURLs[i], photoURLs[i + 1]])
                i += 2
            } else {
                // Trailing single
                groups.append([photoURLs[i]])
                i += 1
            }
        }
        return groups
    }

    @ViewBuilder
    private func tileGroup(_ urls: [URL]) -> some View {
        if urls.count == 1 {
            photoTile(url: urls[0])
                .frame(width: 94, height: bannerHeight)
        } else {
            VStack(spacing: tileGap) {
                photoTile(url: urls[0])
                    .frame(width: 69, height: (bannerHeight - tileGap) / 2)
                photoTile(url: urls[1])
                    .frame(width: 69, height: (bannerHeight - tileGap) / 2)
            }
        }
    }

    private func photoTile(url: URL) -> some View {
        KFImage(url)
            .resizable()
            .placeholder { Color.apolloSkeleton }
            .scaledToFill()
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: tileCornerRadius))
    }
}

// MARK: - Skeleton

struct ProfileBannerSkeletonView: View {
    var body: some View {
        Color.apolloSkeleton
            .frame(maxWidth: .infinity)
            .frame(height: 141)
    }
}

#Preview {
    VStack(spacing: 0) {
        ProfileBannerView(photoURLs: [], isCurrentUser: true)
        ProfileBannerSkeletonView()
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
