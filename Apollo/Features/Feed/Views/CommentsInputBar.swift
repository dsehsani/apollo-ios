//
//  CommentsInputBar.swift
//  Apollo
//
//  Pinned input bar for the Comments sheet per PRD §4C/§4D.
//  Shows current user avatar, pill-style text field (Goudy italic, expands to 3
//  lines), and a send icon. In reply mode an @username pill appears above with
//  an X cancel. Return key inserts newline; only the send icon submits.
//

import SwiftUI
import Kingfisher

struct CommentsInputBar: View {
    var postOwnerUsername: String
    var currentUser: CommentUser
    var replyTo: Comment?

    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var onSubmit: () -> Void
    var onCancelReply: () -> Void

    private let maxCharacters = 300
    private let fieldBackground = Color(red: 0x0a/255, green: 0x0a/255, blue: 0x0a/255)
    private let fieldBorder     = Color(red: 0x14/255, green: 0x14/255, blue: 0x14/255)
    private let sendActive      = Color(red: 0xe8/255, green: 0xe8/255, blue: 0xe8/255)
    private let sendMuted       = Color(red: 0x33/255, green: 0x33/255, blue: 0x33/255)

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if let reply = replyTo {
                replyBadge(for: reply)
                    .padding(.bottom, 6)
            }

            HStack(alignment: .bottom, spacing: 8) {
                userAvatar
                inputPill
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.apolloBackground)
    }

    // MARK: - Reply badge

    private func replyBadge(for comment: Comment) -> some View {
        HStack(spacing: 6) {
            Text("@\(comment.user.username)")
                .font(.sfPro(11, weight: .medium))
                .foregroundStyle(Color(red: 0xe8/255, green: 0xe8/255, blue: 0xe8/255))
                .lineLimit(1)

            Spacer(minLength: 0)

            Button(action: onCancelReply) {
                Image(systemName: "xmark")
                    .font(.sfPro(10, weight: .medium))
                    .foregroundStyle(Color.apolloReactorMuted)
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Color.apolloSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.apolloSurface))
        .padding(.horizontal, 4)
    }

    // MARK: - Avatar

    private var userAvatar: some View {
        Group {
            if let url = currentUser.avatarURL {
                KFImage(url)
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(Circle())
        .padding(.bottom, 10)
    }

    // MARK: - Input pill

    private var inputPill: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(
                "",
                text: $text,
                prompt: Text("Add a comment for \(postOwnerUsername).")
                    .font(.goudyItalic(14))
                    .foregroundStyle(Color(red: 0x1e/255, green: 0x1e/255, blue: 0x1e/255)),
                axis: .vertical
            )
            .font(.goudyItalic(14))
            .foregroundStyle(Color(red: 0xe8/255, green: 0xe8/255, blue: 0xe8/255))
            .lineLimit(1...3)
            .focused($isFocused)
            .onChange(of: text) { _, newValue in
                if newValue.count > maxCharacters {
                    text = String(newValue.prefix(maxCharacters))
                }
            }
            .accessibilityLabel("Add a comment for \(postOwnerUsername). Text field.")

            Button(action: {
                guard canSend else { return }
                onSubmit()
            }) {
                Image(systemName: "arrow.up")
                    .font(.sfPro(12, weight: .semibold))
                    .foregroundStyle(canSend ? sendActive : sendMuted)
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send comment")
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(fieldBackground)
        )
        .overlay(
            Capsule().stroke(fieldBorder, lineWidth: 0.5)
        )
    }
}

#Preview {
    @Previewable @State var text = ""
    @Previewable @FocusState var focused: Bool
    return VStack {
        Spacer()
        CommentsInputBar(
            postOwnerUsername: "jayden",
            currentUser: CommentUser(
                id: UUID(),
                username: "darius",
                avatarURL: URL(string: "https://images.unsplash.com/photo-1502685104226-ee32379fefbe?w=400")
            ),
            replyTo: nil,
            text: $text,
            isFocused: $focused,
            onSubmit: {},
            onCancelReply: {}
        )
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
