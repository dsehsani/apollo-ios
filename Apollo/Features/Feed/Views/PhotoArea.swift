//
//  PhotoArea.swift
//  Apollo
//
//  Renders the photo grid inside a PostCard per Figma 12839:3694.
//
//  Layout — fixed-width left/right split (402 wide, 303 tall total):
//    Main photo (left):  258 × 303
//    3pt gap
//    Tower (right):      141 wide, content varies by photo count
//
//  Per-count tower arrangement:
//    1 photo  — full-width single tile, no tower
//    2 photos — main + one full-height tower tile  (141 × 303)
//    3 photos — main + two stacked tower tiles     (141 × 150 each)
//    4 photos — main + top 141×150 + bottom two-col row (69 × 150 each)
//    5 photos — main + 2×2 tower grid              (69 × 150 each)
//    6 photos — same 2×2 grid, bottom-right tile shows "+1" overflow overlay
//

import SwiftUI
import Kingfisher

struct PhotoArea: View {
    var post: Post
    var featuredIndex: Int
    var onFeaturedPhotoTap: () -> Void
    var onTowerPhotoTap: (Int) -> Void

    // MARK: - Constants (Figma 12839:3694)

    private let mainWidth:   CGFloat = 258
    private let towerWidth:  CGFloat = 141
    private let tileWidth:   CGFloat = 69     // half tower, gap-adjusted
    private let totalHeight: CGFloat = 303
    private let tileHeight:  CGFloat = 150    // half height, gap-adjusted
    private let gap:         CGFloat = 3
    private let cornerRadius: CGFloat = 3

    // Flat ordered URL list: index 0 = main, 1…N = tower (sorted by index).
    private var allURLs: [URL?] {
        var urls: [URL?] = [post.mainPhotoURL]
        urls += post.towerPhotos.sorted { $0.index < $1.index }.map(\.url)
        return urls
    }

    var body: some View {
        switch post.photoCount {
        case 0, 1: singleLayout
        case 2:    twoLayout
        case 3:    threeLayout
        case 4:    fourLayout
        default:   fivePlusLayout
        }
    }

    // MARK: - 1 photo (full width)

    private var singleLayout: some View {
        tile(url: post.mainPhotoURL, index: 0, width: nil, height: totalHeight) {
            onFeaturedPhotoTap()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2 photos (main + single full-height tower tile)

    private var twoLayout: some View {
        HStack(spacing: gap) {
            tile(url: allURLs[safe: 0] ?? nil, index: 0, width: mainWidth, height: totalHeight) {
                onFeaturedPhotoTap()
            }
            tile(url: allURLs[safe: 1] ?? nil, index: 1, width: towerWidth, height: totalHeight) {
                onTowerPhotoTap(1)
            }
        }
    }

    // MARK: - 3 photos (main + two stacked 141×150 tower tiles)

    private var threeLayout: some View {
        HStack(spacing: gap) {
            tile(url: allURLs[safe: 0] ?? nil, index: 0, width: mainWidth, height: totalHeight) {
                onFeaturedPhotoTap()
            }
            VStack(spacing: gap) {
                tile(url: allURLs[safe: 1] ?? nil, index: 1, width: towerWidth, height: tileHeight) {
                    onTowerPhotoTap(1)
                }
                tile(url: allURLs[safe: 2] ?? nil, index: 2, width: towerWidth, height: tileHeight) {
                    onTowerPhotoTap(2)
                }
            }
            .frame(width: towerWidth)
        }
    }

    // MARK: - 4 photos (main + tower: top 141×150 + two 69×150 side-by-side)

    private var fourLayout: some View {
        HStack(spacing: gap) {
            tile(url: allURLs[safe: 0] ?? nil, index: 0, width: mainWidth, height: totalHeight) {
                onFeaturedPhotoTap()
            }
            VStack(spacing: gap) {
                tile(url: allURLs[safe: 1] ?? nil, index: 1, width: towerWidth, height: tileHeight) {
                    onTowerPhotoTap(1)
                }
                HStack(spacing: gap) {
                    tile(url: allURLs[safe: 2] ?? nil, index: 2, width: tileWidth, height: tileHeight) {
                        onTowerPhotoTap(2)
                    }
                    tile(url: allURLs[safe: 3] ?? nil, index: 3, width: tileWidth, height: tileHeight) {
                        onTowerPhotoTap(3)
                    }
                }
            }
            .frame(width: towerWidth)
        }
    }

    // MARK: - 5+ photos (main + 2×2 tower grid of 69×150, overflow overlay on last)

    private var fivePlusLayout: some View {
        let overflow = max(0, post.photoCount - 5)
        return HStack(spacing: gap) {
            tile(url: allURLs[safe: 0] ?? nil, index: 0, width: mainWidth, height: totalHeight) {
                onFeaturedPhotoTap()
            }
            VStack(spacing: gap) {
                // Top row
                HStack(spacing: gap) {
                    tile(url: allURLs[safe: 1] ?? nil, index: 1, width: tileWidth, height: tileHeight) {
                        onTowerPhotoTap(1)
                    }
                    tile(url: allURLs[safe: 2] ?? nil, index: 2, width: tileWidth, height: tileHeight) {
                        onTowerPhotoTap(2)
                    }
                }
                // Bottom row
                HStack(spacing: gap) {
                    tile(url: allURLs[safe: 3] ?? nil, index: 3, width: tileWidth, height: tileHeight) {
                        onTowerPhotoTap(3)
                    }
                    // Bottom-right: overflow overlay when photoCount > 5
                    ZStack {
                        tile(url: allURLs[safe: 4] ?? nil, index: 4, width: tileWidth, height: tileHeight) {
                            onTowerPhotoTap(4)
                        }
                        if overflow > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.black.opacity(0.55))
                                .frame(width: tileWidth, height: tileHeight)
                                .allowsHitTesting(false)
                            Text("+\(overflow)")
                                .font(.sfPro(14, weight: .medium))
                                .foregroundStyle(.white)
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(width: towerWidth)
        }
    }

    // MARK: - Tile helper

    @ViewBuilder
    private func tile(
        url: URL?,
        index: Int,
        width: CGFloat?,
        height: CGFloat,
        onTap: @escaping () -> Void
    ) -> some View {
        Group {
            if let url {
                KFImage(url)
                    .resizable()
                    .placeholder { Color.apolloSkeleton }
                    .scaledToFill()
            } else {
                Color.apolloSkeleton
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityLabel("Photo \(index + 1) of \(post.user.username)'s post")
    }
}

// MARK: - Safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
