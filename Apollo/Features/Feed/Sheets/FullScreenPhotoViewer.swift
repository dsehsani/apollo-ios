//
//  FullScreenPhotoViewer.swift
//  Apollo
//
//  Polaroid-style full-screen photo viewer per Figma 12839:4259 / 12839:4366.
//  Each photo in a post is presented as a polaroid card. The user swipes left/right
//  to page between photos. Vertical drag dismisses the viewer.
//

import SwiftUI
import Kingfisher

// MARK: - Main viewer

struct FullScreenPhotoViewer: View {
    var post: Post
    var startingIndex: Int
    var onClose: () -> Void

    @State private var currentIndex: Int
    @State private var dragOffset: CGFloat = 0

    private var urls: [URL?] {
        var result: [URL?] = [post.mainPhotoURL]
        result += post.towerPhotos.sorted { $0.index < $1.index }.map(\.url)
        return result
    }

    init(post: Post, startingIndex: Int, onClose: @escaping () -> Void) {
        self.post = post
        self.startingIndex = startingIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: max(0, min(startingIndex, max(0, post.photoCount - 1))))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                TabView(selection: $currentIndex) {
                    ForEach(Array(urls.enumerated()), id: \.offset) { idx, url in
                        PolaroidCardView(post: post, url: url)
                            .tag(idx)
                            .padding(.horizontal, 16)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer(minLength: 0)
            }
            .offset(y: dragOffset)
            .gesture(dismissDrag)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.track(.photoViewerOpened, [
                "post_id": post.id.uuidString,
                "starting_index": startingIndex,
                "photo_count": urls.count
            ])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.apolloMuted)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(post.user.username)
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloPrimaryText)

            Spacer()

            Button {
                // TODO: wire to share sheet
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.apolloMuted)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Drag to dismiss

    private var dismissDrag: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.height) > abs(value.translation.width) else { return }
                dragOffset = value.translation.height
            }
            .onEnded { value in
                let dy = value.translation.height
                let predictedDy = value.predictedEndTranslation.height
                if abs(dy) > 120 || abs(predictedDy) > 200 {
                    onClose()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = 0
                    }
                }
            }
    }
}

// MARK: - Polaroid card

private struct PolaroidCardView: View {
    var post: Post
    var url: URL?

    // Figma dimensions: card 368pt wide, 3pt border, 120pt label area
    private let photoWidth: CGFloat = 359   // 368 - 3*2 side padding
    private let labelHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            photoCell
                .padding(.top, 3)
                .padding(.horizontal, 3)

            labelArea
                .frame(height: labelHeight, alignment: .topLeading)
        }
        .background(Color.apolloBackground)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    // MARK: Photo

    @ViewBuilder
    private var photoCell: some View {
        if let url {
            KFImage(url)
                .resizable()
                .placeholder {
                    Color.apolloSkeleton
                        .frame(width: photoWidth, height: photoWidth)
                }
                .scaledToFit()
                .frame(width: photoWidth)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            ZStack {
                Color.apolloSkeleton
                    .frame(width: photoWidth, height: photoWidth)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.apolloIconStroke)
                    Text("Photo unavailable")
                        .font(.sfPro(12))
                        .foregroundStyle(Color.apolloCaption)
                }
            }
        }
    }

    // MARK: Label

    private var labelArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image("ApolloWordmark")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 32)

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloCaption)
                    .lineLimit(1)
            }

            Text(metaLine)
                .font(.sfPro(10))
                .foregroundStyle(Color.apolloWinsLabel)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaLine: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        timeFormatter.amSymbol = "am"
        timeFormatter.pmSymbol = "pm"
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M/d/yy"
        let time = timeFormatter.string(from: post.createdAt)
        let date = dateFormatter.string(from: post.createdAt)
        return "@\(post.user.username) · \(time) · \(date)"
    }
}
