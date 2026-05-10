//
//  CommentRow.swift
//  Apollo
//
//  Renders a single comment (or reply) per PRD §4B. Variable height; min 52pt.
//  Hosts the CommentReactionPicker overlay and forwards all actions up to
//  CommentsViewModel via closures so navigation stays in the sheet.
//

import SwiftUI
import Kingfisher

struct CommentRow: View {
    var comment: Comment
    var isOwn: Bool
    var currentReaction: String?
    var isPickerActive: Bool
    var onReply: () -> Void
    var onDelete: () -> Void
    var onReport: () -> Void
    var onReactionPickerTap: () -> Void
    var onReactionSelect: (String) -> Void
    var onReactionPlusTap: () -> Void

    private let indent: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                avatar
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    metaRow
                    commentText
                    footerRow
                }

                Spacer(minLength: 4)

                reactionButton
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .padding(.leading, comment.parentID != nil ? 16 : 0)
        }
        .contextMenu {
            if isOwn {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button(action: onReport) {
                    Label("Report", systemImage: "flag")
                }
            }
        }
    }

    // MARK: - Avatar

    private var avatar: some View {
        let size: CGFloat = comment.parentID != nil ? 18 : 22
        return Group {
            if let url = comment.user.avatarURL {
                KFImage(url)
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    // MARK: - Meta row (username + timestamp)

    private var metaRow: some View {
        HStack(spacing: 4) {
            Text(comment.user.username)
                .font(.sfPro(10, weight: .medium))
                .foregroundStyle(Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255))
                .lineLimit(1)

            Text(relativeTime(from: comment.createdAt))
                .font(.sfPro(8))
                .foregroundStyle(Color(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255))
        }
    }

    // MARK: - Comment text

    private var commentText: some View {
        Text(comment.text)
            .font(.goudyItalic(12))
            .foregroundStyle(Color(red: 0x55/255, green: 0x55/255, blue: 0x55/255))
            .padding(.leading, indent)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Footer row (Reply + reactions line)

    private var footerRow: some View {
        HStack(spacing: 6) {
            Button(action: onReply) {
                Text("Reply")
                    .font(.sfPro(8))
                    .foregroundStyle(Color(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255))
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel("Reply to \(comment.user.username)")

            if !comment.reactions.isEmpty {
                CommentReactionsLine(reactions: comment.reactions)
            }
        }
        .padding(.leading, indent)
    }

    // MARK: - Smiley reaction button + picker

    private var reactionButton: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onReactionPickerTap) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color(red: 0x11/255, green: 0x11/255, blue: 0x11/255)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("React to comment")

            if isPickerActive {
                CommentReactionPicker(
                    currentReaction: currentReaction,
                    onSelect: onReactionSelect,
                    onPlusTap: onReactionPlusTap
                )
                .offset(y: -26)
                .animation(.easeOut(duration: 0.2), value: isPickerActive)
            }
        }
        .padding(.top, 10)
    }

    // MARK: - Relative time

    private func relativeTime(from date: Date) -> String {
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 60    { return "now" }
        if diff < 3600  { return "\(diff / 60)m" }
        if diff < 86400 { return "\(diff / 3600)h" }
        return "\(diff / 86400)d"
    }
}

// MARK: - Inline emoji strip

struct CommentReactionsLine: View {
    var reactions: [CommentReaction]

    /// Deduplicated emoji list in order of first appearance.
    private var dedupedEmojis: [String] {
        var seen = Set<String>()
        return reactions.compactMap { r in
            seen.insert(r.emoji).inserted ? r.emoji : nil
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(dedupedEmojis, id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: 12))
            }
        }
    }
}

// MARK: - Preview

#Preview("Top-level") {
    let comment = Comment(
        id: UUID(),
        postID: UUID(),
        userID: UUID(),
        user: CommentUser(
            id: UUID(),
            username: "jayden",
            avatarURL: URL(string: "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400")
        ),
        text: "This is the type of W that compounds. Keep stacking.",
        createdAt: Date().addingTimeInterval(-45 * 60),
        parentID: nil,
        reactions: [
            CommentReaction(id: UUID(), commentID: UUID(), userID: UUID(), username: "mira", avatarURL: nil, emoji: "❤️", createdAt: .now),
        ],
        replyCount: 2
    )
    return CommentRow(
        comment: comment,
        isOwn: false,
        currentReaction: nil,
        isPickerActive: false,
        onReply: {},
        onDelete: {},
        onReport: {},
        onReactionPickerTap: {},
        onReactionSelect: { _ in },
        onReactionPlusTap: {}
    )
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
