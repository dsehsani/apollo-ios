//
//  PhotoArea.swift
//  Apollo
//

import SwiftUI
import Kingfisher

struct PhotoArea: View {
    var post: Post
    var featuredIndex: Int
    var onFeaturedPhotoTap: () -> Void
    var onTowerPhotoTap: (Int) -> Void

    private let totalHeight: CGFloat = 303
    private let featuredWidthMulti: CGFloat = 258
    private let towerWidth: CGFloat = 141
    private let gap: CGFloat = 3
    private let cornerRadius: CGFloat = 3

    var body: some View {
        if post.photoCount <= 1 {
            singlePhoto
        } else {
            multiPhoto
        }
    }

    @ViewBuilder
    private var singlePhoto: some View {
        Group {
            if let url = post.mainPhotoURL {
                KFImage(url)
                    .resizable()
                    .placeholder { Color.apolloSkeleton }
                    .scaledToFill()
            } else {
                Color.apolloSkeleton
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: totalHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onFeaturedPhotoTap)
        .accessibilityLabel("Featured photo for \(post.user.username)'s post")
    }

    private var multiPhoto: some View {
        HStack(alignment: .top, spacing: gap) {
            featuredView
            PhotoTower(
                photos: post.towerPhotos,
                onPhotoTap: { slot in
                    onTowerPhotoTap(slot.index)
                }
            )
            .frame(width: towerWidth, height: totalHeight)
        }
        .frame(height: totalHeight)
    }

    @ViewBuilder
    private var featuredView: some View {
        Group {
            if let url = featuredURL {
                KFImage(url)
                    .resizable()
                    .placeholder { Color.apolloSkeleton }
                    .scaledToFill()
            } else {
                Color.apolloSkeleton
            }
        }
        .frame(width: featuredWidthMulti, height: totalHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(Rectangle())
        .onTapGesture(perform: onFeaturedPhotoTap)
        .accessibilityLabel("Featured photo for \(post.user.username)'s post")
        .animation(.easeInOut(duration: 0.25), value: featuredURL)
        .id(featuredURL)
    }

    private var featuredURL: URL? {
        if featuredIndex == 0 || featuredIndex < 0 {
            return post.mainPhotoURL
        }
        let towerIdx = featuredIndex - 1
        if towerIdx >= 0 && towerIdx < post.towerPhotos.count {
            return post.towerPhotos[towerIdx].url
        }
        return post.mainPhotoURL
    }
}
