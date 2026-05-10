//
//  PhotoTower.swift
//  Apollo
//
//  Renders the right-side multi-photo tower for posts with more than one photo.
//  The tower fills `MaxPhotosPerDay` (6) slots with a deterministic 4-cell rhythm:
//
//      index 0: pair-left   (69 × 85)
//      index 1: pair-right  (69 × 85)
//      index 2: wide        (141 × 71)
//      index 3: square      (141 × 141)
//
//  Pair-left and pair-right share one row inside an HStack(spacing: 3); wide
//  and square each occupy their own row inside the outer LazyVStack(spacing: 3).
//  When `photos.count < MaxPhotosPerDay`, skeleton blocks fill from the top and
//  real photos sit at the bottom — same loading semantics as before, just
//  rendered with the new variable cell shapes.
//

import SwiftUI
import Kingfisher

struct PhotoTower: View {
    var photos: [PhotoSlot]
    var onPhotoTap: (PhotoSlot) -> Void

    private let pairCellWidth: CGFloat = 69
    private let pairCellHeight: CGFloat = 85
    private let wideHeight: CGFloat = 71
    private let squareSide: CGFloat = 141
    private let gap: CGFloat = 3
    private let cornerRadius: CGFloat = 3

    private enum CellContent: Hashable {
        case skeleton(Int)
        case photo(PhotoSlot)
    }

    private enum CellShape {
        case pairLeft, pairRight, wide, square

        var size: CGSize {
            switch self {
            case .pairLeft, .pairRight: return CGSize(width: 69, height: 85)
            case .wide: return CGSize(width: 141, height: 71)
            case .square: return CGSize(width: 141, height: 141)
            }
        }
    }

    private var orderedCells: [CellContent] {
        let skeletonCount = max(0, MaxPhotosPerDay - photos.count)
        var result: [CellContent] = []
        for i in 0..<skeletonCount {
            result.append(.skeleton(i))
        }
        for p in photos {
            result.append(.photo(p))
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: gap) {
                    let cells = orderedCells
                    let groupCount = (cells.count + 3) / 4
                    ForEach(0..<groupCount, id: \.self) { g in
                        let start = g * 4
                        let end = min(start + 4, cells.count)
                        let group = Array(cells[start..<end])

                        if !group.isEmpty {
                            HStack(spacing: gap) {
                                cellView(group[0], shape: .pairLeft)
                                if group.count >= 2 {
                                    cellView(group[1], shape: .pairRight)
                                } else {
                                    Color.clear
                                        .frame(width: pairCellWidth, height: pairCellHeight)
                                }
                            }
                        }

                        if group.count >= 3 {
                            cellView(group[2], shape: .wide)
                        }

                        if group.count >= 4 {
                            cellView(group[3], shape: .square)
                        }
                    }
                }
            }
            .background(Color.apolloBackground)
            .onAppear {
                if let last = photos.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: photos.last?.id) { _, newID in
                if let newID {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(newID, anchor: .bottom)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: CellContent, shape: CellShape) -> some View {
        switch cell {
        case .photo(let slot):
            Button {
                onPhotoTap(slot)
            } label: {
                photoContent(slot, shape: shape)
            }
            .buttonStyle(.plain)
            .id(slot.id)

        case .skeleton(let i):
            Rectangle()
                .fill(Color.apolloSkeleton)
                .frame(width: shape.size.width, height: shape.size.height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .accessibilityLabel("Loading photo")
                .id("skeleton-\(i)")
        }
    }

    @ViewBuilder
    private func photoContent(_ photo: PhotoSlot, shape: CellShape) -> some View {
        Group {
            if let url = photo.url {
                KFImage(url)
                    .resizable()
                    .placeholder { Color.apolloSkeleton }
                    .scaledToFill()
            } else {
                Color.apolloSkeleton
            }
        }
        .frame(width: shape.size.width, height: shape.size.height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
