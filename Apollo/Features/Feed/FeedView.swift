//
//  FeedView.swift
//  Apollo
//
//  The Feed screen — Apollo's primary social surface. Composes the nav bar,
//  tab row, and a phase-driven scroll container of PostCards. Owns navigation
//  destinations (push, sheet, full-screen cover, action sheet, alerts) and
//  routes them to placeholder screens that future agents can swap in.
//

import SwiftUI

struct FeedView: View {
    @State private var viewModel: FeedViewModel
    @State private var navigationPath = NavigationPath()
    @State private var sheetItem: FeedSheetItem?
    @State private var fullScreenItem: FeedFullScreenItem?
    @State private var actionSheetPost: Post?
    @State private var isActionSheetPresented = false
    @State private var deleteCandidate: Post?

    init(repository: FeedRepository = MockFeedRepository()) {
        _viewModel = State(initialValue: FeedViewModel(repository: repository))
    }

    init(viewModel: FeedViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    FeedTabRow(selected: viewModel.tab) { tab in
                        viewModel.switchTab(tab)
                    }
                    .padding(.bottom, 12)

                    contentArea
                }

                if let message = viewModel.transientErrorMessage {
                    ErrorToast(
                        message: message,
                        actionLabel: viewModel.phase == .error ? "Try again" : nil,
                        onAction: viewModel.phase == .error ? {
                            viewModel.clearTransientError()
                            Task { await viewModel.load(initial: true) }
                        } : nil,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.clearTransientError()
                            }
                        }
                    )
                    .padding(.top, 4)
                    .zIndex(10)
                }

                if !viewModel.pendingNewPosts.isEmpty {
                    NewPostsBanner(count: viewModel.pendingNewPostsCount) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.applyPendingNewPosts()
                        }
                    }
                    .padding(.top, 110)
                    .zIndex(5)
                }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [Color.apolloBackground.opacity(0), Color.apolloBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 91)
                    .frame(maxWidth: .infinity)
                }
                .allowsHitTesting(false)
                .zIndex(2)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Image("ApolloWordmark")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 28)
                        .accessibilityLabel("Apollo")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationPath.append(FeedDestination.notifications)
                    } label: {
                        Image("IconBell")
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 22, height: 22)
                            .foregroundStyle(Color.apolloPrimaryText)
                    }
                    .accessibilityLabel("Notifications")
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .navigationDestination(for: FeedDestination.self) { dest in
                switch dest {
                case .notifications:
                    NotificationsPlaceholderView()
                case .profile(let user):
                    ProfilePlaceholderView(user: user)
                case .shareStrip(let post):
                    ShareStripPlaceholder(post: post)
                }
            }
            .sheet(item: $sheetItem) { item in
                switch item {
                case .comments(let post):
                    CommentsSheetPlaceholder(post: post)
                case .reactions(let post):
                    ReactionsBreakdownSheetPlaceholder(post: post)
                case .report(let post):
                    ReportFlowPlaceholder(post: post) {
                        sheetItem = nil
                    }
                }
            }
            .fullScreenCover(item: $fullScreenItem) { item in
                switch item {
                case .photoViewer(let post, let index):
                    FullScreenPhotoViewerPlaceholder(post: post, startingIndex: index) {
                        fullScreenItem = nil
                    }
                case .camera:
                    CameraView(onClose: {
                        fullScreenItem = nil
                    })
                }
            }
            .postActionSheet(
                post: actionSheetPost,
                isOwnPost: actionSheetPost.map(viewModel.isOwnPost) ?? false,
                isPresented: $isActionSheetPresented,
                onIntent: handleActionSheetIntent
            )
            .alert(
                "Delete this post?",
                isPresented: .init(
                    get: { deleteCandidate != nil },
                    set: { if !$0 { deleteCandidate = nil } }
                ),
                presenting: deleteCandidate
            ) { post in
                Button("Delete", role: .destructive) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.delete(post: post)
                    }
                    deleteCandidate = nil
                }
                Button("Cancel", role: .cancel) {
                    deleteCandidate = nil
                }
            } message: { _ in
                Text("This can't be undone.")
            }
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Content area (phase-driven)

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.phase {
        case .loading:
            ScrollView {
                FeedSkeleton().padding(.top, 8)
            }
        case .loaded:
            postsScroll
        case .empty:
            EmptyFeedView {
                fullScreenItem = .camera
            }
        case .partial:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.posts) { post in
                        postCard(for: post)
                    }
                    PartialEmptyView()
                    EndOfFeedView(quote: viewModel.quote)
                }
            }
            .refreshable { await viewModel.refresh() }
        case .yesterdayEmpty:
            YesterdayEmptyView()
        case .error:
            ScrollView {
                FeedSkeleton().padding(.top, 8).opacity(0.4)
            }
            .refreshable { await viewModel.refresh() }
        }
    }

    private var postsScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.posts) { post in
                    postCard(for: post)
                }

                if viewModel.isLoadingMore {
                    Circle()
                        .fill(Color.apolloMuted)
                        .frame(width: 6, height: 6)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                if !viewModel.hasMore {
                    EndOfFeedView(quote: viewModel.quote)
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await viewModel.refresh() }
        .simultaneousGesture(
            TapGesture().onEnded {
                if viewModel.activeReactionPicker != nil {
                    viewModel.dismissReactionPicker()
                }
            }
        )
    }

    private func postCard(for post: Post) -> some View {
        PostCard(
            viewModel: viewModel,
            post: post,
            onProfileTap: { user in
                navigationPath.append(FeedDestination.profile(user))
            },
            onMoreTap: { post in
                actionSheetPost = post
                isActionSheetPresented = true
            },
            onCommentTap: { post in
                sheetItem = .comments(post)
            },
            onReactionsLineTap: { post in
                sheetItem = .reactions(post)
            },
            onPhotoTap: { post, index in
                fullScreenItem = .photoViewer(post, index)
            }
        )
        .id(post.id)
    }

    // MARK: - Action sheet routing

    private func handleActionSheetIntent(_ intent: PostActionSheetIntent) {
        switch intent {
        case .editOwn(let post):
            sheetItem = .comments(post)
            // TODO: route to Post Details Sheet when that screen ships.
        case .shareStripOwn(let post):
            navigationPath.append(FeedDestination.shareStrip(post))
        case .deleteOwn(let post):
            deleteCandidate = post
        case .shareOthers:
            // TODO: present iOS Share Sheet with post URL when share infra exists.
            viewModel.transientErrorMessage = "Share sheet coming soon."
        case .reportOthers(let post):
            sheetItem = .report(post)
        }
    }
}

// MARK: - Routing types

enum FeedDestination: Hashable {
    case notifications
    case profile(PostUser)
    case shareStrip(Post)
}

enum FeedSheetItem: Identifiable {
    case comments(Post)
    case reactions(Post)
    case report(Post)

    var id: String {
        switch self {
        case .comments(let p): return "comments-\(p.id)"
        case .reactions(let p): return "reactions-\(p.id)"
        case .report(let p): return "report-\(p.id)"
        }
    }
}

enum FeedFullScreenItem: Identifiable {
    case photoViewer(Post, Int)
    case camera

    var id: String {
        switch self {
        case .photoViewer(let p, let i): return "photo-\(p.id)-\(i)"
        case .camera: return "camera"
        }
    }
}

// MARK: - Previews

#Preview("Loaded") {
    FeedView(repository: MockFeedRepository(forceState: .loaded))
}

#Preview("Empty") {
    FeedView(repository: MockFeedRepository(forceState: .empty))
}

#Preview("Partial") {
    FeedView(repository: MockFeedRepository(forceState: .partial))
}

#Preview("Yesterday Empty") {
    FeedView(repository: MockFeedRepository(forceState: .yesterdayEmpty))
}

#Preview("Error") {
    FeedView(repository: MockFeedRepository(forceState: .error))
}
