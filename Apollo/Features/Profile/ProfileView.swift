//
//  ProfileView.swift
//  Apollo
//
//  Profile screen (PRD §06). Displays an inline hero header (36pt Goudy
//  "Profile" title + circular icon buttons), banner, avatar, name, stats,
//  and TODAY'S WINS section.
//

import SwiftUI

struct ProfileView: View {
    @State private var viewModel: ProfileViewModel
    @State private var showBannerEditSheet = false

    init(userID: UUID = UUID()) {
        _viewModel = State(initialValue: ProfileViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                ScrollView {
                    switch viewModel.phase {
                    case .loading:
                        skeletonContent
                    case .loaded(let user, let post):
                        loadedContent(user: user, post: post)
                    case .error(let message):
                        errorContent(message: message)
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refresh() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .apolloProfileShouldRefresh)) { _ in
            Task { await viewModel.refresh() }
        }
        .sheet(isPresented: $showBannerEditSheet) {
            bannerEditSheet
        }
    }

    // MARK: Inline hero bar

    private func heroBar(isCurrentUser: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Profile")
                .font(.goudyRegular(36))
                .foregroundStyle(Color.apolloPrimaryText)

            Spacer()

            HStack(spacing: 24) {
                circleIconButton(systemName: "calendar", action: {})
                if isCurrentUser {
                    circleIconButton(systemName: "bell", action: {})
                } else {
                    Menu {
                        Button("Add friend", action: {})
                        Button("Remove friend", action: {})
                        Button(role: .destructive) {} label: { Text("Report") }
                    } label: {
                        circleIconLabel(systemName: "ellipsis")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func circleIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circleIconLabel(systemName: systemName)
        }
        .buttonStyle(.plain)
    }

    private func circleIconLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Color.apolloPrimaryText)
            .frame(width: 40, height: 40)
            .background(Color.apolloSkeleton)
            .clipShape(Circle())
    }

    // MARK: Loaded state

    @ViewBuilder
    private func loadedContent(user: ProfileUser, post: ProfilePost?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBar(isCurrentUser: user.isCurrentUser)

            ProfileBannerView(
                photoURLs: user.bannerPhotoURLs,
                isCurrentUser: user.isCurrentUser,
                onTap: { showBannerEditSheet = true }
            )

            ProfileHeaderView(user: user)
                .padding(.top, 16)

            if let post {
                TodaysWinsSection(
                    post: post,
                    isCurrentUser: user.isCurrentUser,
                    featuredPhotoIndex: viewModel.featuredPhotoIndex,
                    onFeaturedPhotoTap: {},
                    onTowerPhotoTap: { idx in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.setFeaturedPhoto(idx + 1)
                        }
                    },
                    onMoreTap: {},
                    onReactionsLineTap: {},
                    onCommentTap: {}
                )
                .padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    emptyWinsHeader
                    TodaysWinsEmptyView(onCameraTap: {})
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 48)
        }
    }

    private var emptyWinsHeader: some View {
        Text("TODAY'S WINS")
            .font(.sfPro(15))
            .foregroundStyle(Color.apolloTimeStreak)
            .padding(.horizontal, 16)
            .padding(.top, 24)
    }

    // MARK: Skeleton state

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBar(isCurrentUser: true)

            ProfileBannerSkeletonView()
            ProfileHeaderSkeletonView()
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 100, height: 10)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                Color.apolloSkeleton
                    .frame(maxWidth: .infinity)
                    .frame(height: 303)
            }
        }
    }

    // MARK: Error state

    private func errorContent(message: String) -> some View {
        VStack(spacing: 20) {
            heroBar(isCurrentUser: true)
            Spacer()
            Text(message)
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloCaption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await viewModel.load() }
            }
            .font(.sfPro(15, weight: .semibold))
            .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 500)
    }

    // MARK: Banner edit sheet (v1 placeholder)

    private var bannerEditSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.apolloStroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                sheetOption("Choose from camera roll") {}
                Divider().background(Color.apolloBorder)
                sheetOption("Choose from my wins") {}
                Divider().background(Color.apolloBorder)
                sheetOption("Reset to auto") {}
            }
            .background(Color.apolloSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.apolloBackground.ignoresSafeArea())
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.hidden)
    }

    private func sheetOption(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
