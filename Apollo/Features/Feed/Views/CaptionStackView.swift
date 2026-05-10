//
//  CaptionStackView.swift
//  Apollo
//
//  Renders a day's per-photo captions as a clean stacked log.
//  Lines are ordered by photo position; blank captions are omitted.
//  Falls back to post.caption (legacy) when no per-photo captions exist.
//

import SwiftUI

struct CaptionStackView: View {
    var post: Post

    private let captionFont: Font = .sfPro(14)
    private let captionColor = Color(white: 0xe8 / 255.0)
    private let maxWidth: CGFloat = 215

    var body: some View {
        let lines = captionLines
        if lines.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .trailing, spacing: 4) {
                ForEach(lines.indices, id: \.self) { idx in
                    Text(lines[idx])
                        .font(captionFont)
                        .foregroundStyle(captionColor)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: maxWidth, alignment: .trailing)
                }
            }
            .frame(maxWidth: maxWidth, alignment: .trailing)
        )
    }

    /// Ordered non-empty caption lines: per-photo first, then falls back to post.caption.
    var captionLines: [String] {
        let perPhoto = ([post.mainPhotoCaption] + post.towerPhotos.map(\.caption))
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !perPhoto.isEmpty { return perPhoto }

        let fallback = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? [] : [fallback]
    }
}

/// Convenience: returns true when there is nothing to render, so callers can
/// omit the entire column from the layout.
extension CaptionStackView {
    var isEmpty: Bool { captionLines.isEmpty }
}

#Preview {
    let makeSlot = { (idx: Int, cap: String?) -> PhotoSlot in
        PhotoSlot(id: UUID(), url: nil, index: idx, caption: cap)
    }
    let multiPost = Post(
        id: UUID(), user: PostUser(id: UUID(), username: "darius", avatarURL: nil, streak: 7),
        createdAt: .now, caption: "",
        mainPhotoCaption: "Morning run done 🏃",
        photoCount: 3, mainPhotoURL: nil,
        towerPhotos: [makeSlot(1, "Meal prepped for the week"), makeSlot(2, "Hit the gym after work 💪")],
        winsCount: 3, reactions: [], commentCount: 0, currentUserReaction: nil
    )
    let singlePost = Post(
        id: UUID(), user: PostUser(id: UUID(), username: "darius", avatarURL: nil, streak: 3),
        createdAt: .now, caption: "",
        mainPhotoCaption: "Just one caption",
        photoCount: 1, mainPhotoURL: nil, towerPhotos: [],
        winsCount: 1, reactions: [], commentCount: 0, currentUserReaction: nil
    )
    let fallbackPost = Post(
        id: UUID(), user: PostUser(id: UUID(), username: "darius", avatarURL: nil, streak: 1),
        createdAt: .now, caption: "Legacy post caption",
        photoCount: 1, mainPhotoURL: nil, towerPhotos: [],
        winsCount: 1, reactions: [], commentCount: 0, currentUserReaction: nil
    )
    let nonePost = Post(
        id: UUID(), user: PostUser(id: UUID(), username: "darius", avatarURL: nil, streak: 1),
        createdAt: .now, caption: "",
        photoCount: 1, mainPhotoURL: nil, towerPhotos: [],
        winsCount: 1, reactions: [], commentCount: 0, currentUserReaction: nil
    )
    return VStack(alignment: .trailing, spacing: 24) {
        CaptionStackView(post: multiPost)
        Divider()
        CaptionStackView(post: singlePost)
        Divider()
        CaptionStackView(post: fallbackPost)
        Divider()
        CaptionStackView(post: nonePost)
        Text("(empty — nothing above this line)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .trailing)
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
