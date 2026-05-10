//
//  PostCard.swift
//  Apollo
//
//  Renders one post: header, photo area, then a row pairing the caption
//  (right-aligned, max 215pt) with the action buttons (comment, react), and
//  the reactions line below. All callbacks bubble up to FeedView so navigation
//  lives at the screen level.
//

import SwiftUI

struct PostCard: View {
    @Bindable var viewModel: FeedViewModel
    var post: Post

    var onProfileTap: (PostUser) -> Void
    var onMoreTap: (Post) -> Void
    var onCommentTap: (Post) -> Void
    var onReactionsLineTap: (Post) -> Void
    var onPhotoTap: (Post, Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PostHeader(
                post: post,
                onAvatarTap: { onProfileTap(post.user) },
                onUsernameTap: { onProfileTap(post.user) },
                onMoreTap: { onMoreTap(post) }
            )

            PhotoArea(
                post: post,
                featuredIndex: viewModel.featuredIndex(for: post),
                onFeaturedPhotoTap: {
                    onPhotoTap(post, viewModel.featuredIndex(for: post))
                },
                onTowerPhotoTap: { towerIdx in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.setFeaturedIndex(towerIdx + 1, for: post)
                    }
                }
            )
            .padding(.top, 8)

            HStack(alignment: .top, spacing: 0) {
                CaptionView(
                    caption: post.caption,
                    isExpanded: viewModel.expandedCaptions.contains(post.id),
                    onTapMore: { viewModel.toggleCaptionExpansion(post.id) }
                )
                .frame(maxWidth: 215, alignment: .trailing)
                .padding(.leading, 16)

                Spacer(minLength: 8)

                ZStack(alignment: .bottomTrailing) {
                    ActionRow(
                        onCommentTap: { onCommentTap(post) },
                        onReactionTap: {
                            if viewModel.activeReactionPicker == post.id {
                                viewModel.dismissReactionPicker()
                            } else {
                                viewModel.openReactionPicker(for: post.id)
                            }
                        }
                    )
                    if viewModel.activeReactionPicker == post.id {
                        ReactionPicker(
                            currentReaction: post.currentUserReaction,
                            onSelect: { emoji in
                                viewModel.toggleReaction(post: post, emoji: emoji)
                            },
                            onPlusTap: {
                                viewModel.requestCustomEmoji(for: post.id)
                            }
                        )
                        .offset(y: -52)
                        .animation(.easeOut(duration: 0.2), value: viewModel.activeReactionPicker)
                    }
                }
                .padding(.trailing, 16)
            }
            .padding(.top, 7)

            ReactionsLine(
                reactions: post.reactions,
                onTap: { onReactionsLineTap(post) }
            )
            .padding(.top, 23)
        }
        .background(Color.apolloBackground)
        .padding(.bottom, 23)
        .onAppear {
            viewModel.loadMoreIfNeeded(currentPost: post)
        }
    }
}
