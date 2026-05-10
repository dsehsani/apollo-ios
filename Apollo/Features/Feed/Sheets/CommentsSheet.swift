//
//  CommentsSheet.swift
//  Apollo
//
//  Full Comments sheet per PRD §09. Presents as a large bottom sheet over the
//  feed. Owns header (drag pill + "Comments" title + border), phase-driven
//  content area, and a pinned CommentsInputBar via safeAreaInset. Auto-focuses
//  the input on appear per acceptance criterion §17.1.
//

import SwiftUI

struct CommentsSheet: View {
    var post: Post
    var repository: CommentsRepository

    @State private var viewModel: CommentsViewModel
    @FocusState private var inputFocused: Bool

    init(post: Post, repository: CommentsRepository) {
        self.post       = post
        self.repository = repository
        _viewModel = State(initialValue: CommentsViewModel(
            postID: post.id,
            postOwnerUsername: post.user.username,
            repository: repository
        ))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                    .background(Color(red: 0x0f/255, green: 0x0f/255, blue: 0x0f/255))
                    .frame(height: 0.5)

                contentArea
            }

            // Transient error toast
            if let message = viewModel.transientErrorMessage {
                ErrorToast(
                    message: message,
                    actionLabel: nil,
                    onAction: nil,
                    onDismiss: { viewModel.clearTransientError() }
                )
                .padding(.top, 4)
                .zIndex(10)
            }
        }
        .safeAreaInset(edge: .bottom) {
            CommentsInputBar(
                postOwnerUsername: post.user.username,
                currentUser: repository.currentUser,
                replyTo: viewModel.replyTo,
                text: $viewModel.inputText,
                isFocused: $inputFocused,
                onSubmit: {
                    viewModel.submit()
                },
                onCancelReply: {
                    viewModel.cancelReply()
                }
            )
        }
        .alert(
            "Delete this comment?",
            isPresented: .init(
                get: { viewModel.deleteCandidate != nil },
                set: { if !$0 { viewModel.deleteCandidate = nil } }
            ),
            presenting: viewModel.deleteCandidate
        ) { comment in
            Button("Delete", role: .destructive) {
                viewModel.delete(comment: comment)
                viewModel.deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) {
                viewModel.deleteCandidate = nil
            }
        } message: { _ in
            Text("This can't be undone.")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .task {
            viewModel.onAppear()
            Analytics.track(.commentsOpened, [
                "post_id": post.id.uuidString,
                "comment_count": post.commentCount
            ])
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onAppear {
            inputFocused = true
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 0) {
            // Drag pill
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0x22/255, green: 0x22/255, blue: 0x22/255))
                .frame(width: 32, height: 4)
                .padding(.top, 10)

            HStack {
                Text("Comments")
                    .font(.goudyItalic(18))
                    .foregroundStyle(Color.apolloText)
                    .padding(.leading, 12)
                    .padding(.top, 8)
                Spacer()
            }
            .padding(.bottom, 10)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                CommentSkeleton()
                    .padding(.top, 8)
            }

        case .loaded:
            if viewModel.displayedComments.isEmpty {
                emptyState
            } else {
                commentsList
            }

        case .error:
            VStack(spacing: 12) {
                Text("Couldn't load comments.")
                    .font(.sfPro(14))
                    .foregroundStyle(Color.apolloReactorMuted)
                Button("Try again") {
                    Task { await viewModel.load() }
                }
                .font(.sfPro(13, weight: .medium))
                .foregroundStyle(Color.apolloPrimaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyState: some View {
        Spacer()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.displayedComments) { comment in
                    CommentRow(
                        comment: comment,
                        isOwn: viewModel.isOwnComment(comment),
                        onReply: {
                            viewModel.startReply(to: comment)
                            inputFocused = true
                        },
                        onDelete: {
                            viewModel.deleteCandidate = comment
                        },
                        onReport: {
                            viewModel.transientErrorMessage = "Report submitted."
                        }
                    )
                    .id(comment.id)
                    .onAppear {
                        viewModel.loadMoreIfNeeded(currentComment: comment)
                    }
                }

                if viewModel.isLoadingMore {
                    Circle()
                        .fill(Color.apolloMuted)
                        .frame(width: 6, height: 6)
                        .padding(.vertical, 12)
                }
            }
            .padding(.bottom, 8)
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

// MARK: - Previews

#Preview("Populated") {
    let postID = UUID(uuidString: "22222222-0000-0000-0000-000000000001")!
    let post = Post(
        id: postID,
        user: PostUser(id: UUID(), username: "jayden", avatarURL: nil, streak: 10),
        createdAt: Date(),
        caption: "Preview",
        photoCount: 1,
        mainPhotoURL: nil,
        towerPhotos: [],
        winsCount: 1,
        reactions: [],
        commentCount: 5,
        currentUserReaction: nil
    )
    return CommentsSheet(post: post, repository: MockCommentsRepository(forceState: .populated))
}

#Preview("Empty") {
    let postID = UUID()
    let post = Post(
        id: postID,
        user: PostUser(id: UUID(), username: "rildy", avatarURL: nil, streak: 7),
        createdAt: Date(),
        caption: "Preview",
        photoCount: 1,
        mainPhotoURL: nil,
        towerPhotos: [],
        winsCount: 1,
        reactions: [],
        commentCount: 0,
        currentUserReaction: nil
    )
    return CommentsSheet(post: post, repository: MockCommentsRepository(forceState: .empty))
}

#Preview("Error") {
    let postID = UUID()
    let post = Post(
        id: postID,
        user: PostUser(id: UUID(), username: "mira", avatarURL: nil, streak: 41),
        createdAt: Date(),
        caption: "Preview",
        photoCount: 1,
        mainPhotoURL: nil,
        towerPhotos: [],
        winsCount: 1,
        reactions: [],
        commentCount: 0,
        currentUserReaction: nil
    )
    return CommentsSheet(post: post, repository: MockCommentsRepository(forceState: .error))
}
