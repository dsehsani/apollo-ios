//
//  ReactionsBreakdownSheet.swift
//  Apollo
//
//  Reactions breakdown sheet per PRD §4C. Shows a filterable list of who reacted
//  and with what, sorted most-recent first, capped at 50 results.
//

import SwiftUI

private let maxShown = 50

struct ReactionsBreakdownSheet: View {
    var post: Post
    var repository: FeedRepository
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ReactionsBreakdownViewModel

    init(post: Post, repository: FeedRepository) {
        self.post = post
        self.repository = repository
        _viewModel = State(initialValue: ReactionsBreakdownViewModel(postID: post.id, repository: repository))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                switch viewModel.phase {
                case .loading:
                    Spacer()
                    ProgressView()
                        .tint(Color.apolloReactorMuted)
                    Spacer()

                case .error:
                    Spacer()
                    Text(viewModel.errorMessage ?? "Couldn't load reactions.")
                        .font(.sfPro(14))
                        .foregroundStyle(Color.apolloReactorMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()

                case .loaded:
                    if viewModel.reactions.isEmpty {
                        Spacer()
                        Text("No reactions yet.")
                            .font(.sfPro(14))
                            .foregroundStyle(Color.apolloReactorMuted)
                        Spacer()
                    } else {
                        loadedContent
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text("Reactions")
                .font(.sfPro(14))
                .foregroundStyle(Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255))

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.sfPro(11, weight: .medium))
                    .foregroundStyle(Color.apolloReactorMuted)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.apolloSurface))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close reactions")
        }
        .padding(.horizontal, 16)
    }

    private var loadedContent: some View {
        VStack(spacing: 0) {
            if viewModel.availableFilters.count > 1 {
                ReactionsBreakdownFilterTabs(
                    filters: viewModel.availableFilters,
                    counts: viewModel.counts,
                    totalCount: viewModel.totalCount,
                    selected: viewModel.selectedFilter,
                    onSelect: { viewModel.select(filter: $0) }
                )
                .padding(.bottom, 8)
            }

            let displayed = Array(viewModel.filteredReactions.prefix(maxShown))

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayed) { reaction in
                        ReactionsBreakdownRow(reaction: reaction)
                            .padding(.horizontal, 16)
                    }

                    if viewModel.filteredReactions.count > maxShown {
                        Text("View all \(viewModel.filteredReactions.count)")
                            .font(.sfPro(12))
                            .foregroundStyle(Color.apolloReactorMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }
}

#Preview("Loaded") {
    let repo = MockFeedRepository(forceState: .loaded)
    let post = {
        var p = Post(
            id: UUID(uuidString: "22222222-0000-0000-0000-000000000001")!,
            user: PostUser(id: UUID(), username: "jayden", avatarURL: nil, streak: 10),
            createdAt: Date(),
            caption: "Preview post",
            photoCount: 1,
            mainPhotoURL: nil,
            towerPhotos: [],
            winsCount: 1,
            reactions: [],
            commentCount: 0,
            currentUserReaction: nil
        )
        return p
    }()
    return ReactionsBreakdownSheet(post: post, repository: repo)
        .preferredColorScheme(.dark)
}
