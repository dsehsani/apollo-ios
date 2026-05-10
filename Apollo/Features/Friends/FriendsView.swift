//
//  FriendsView.swift
//  Apollo
//
//  Friends screen (PRD §07). Shows "Connect" hero, Friends/Challenges sub-tabs,
//  search pill, Requests, Recommended, Invite Card, and Invite Friends sections.
//  While the search bar has text, the main sections are replaced by search results.
//

import SwiftUI
import Supabase
import Auth

struct FriendsView: View {
    @EnvironmentObject private var notificationsService: NotificationsService
    @State private var viewModel: FriendsViewModel
    @State private var selectedTab: FriendsTab = .friends

    init(currentUser: CurrentUser?) {
        let userID = currentUser?.id ?? supabase.auth.currentUser?.id ?? UUID()
        _viewModel = State(initialValue: FriendsViewModel(currentUserID: userID))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                switch viewModel.phase {
                case .loading:
                    skeletonContent
                case .loaded(let data):
                    loadedContent(data: data)
                case .error(let message):
                    errorContent(message: message)
                }

                // Error toast overlay
                if let msg = viewModel.toastMessage {
                    VStack {
                        ErrorToast(message: msg, onDismiss: {
                            viewModel.toastMessage = nil
                        })
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeOut(duration: 0.3), value: viewModel.toastMessage)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.load()
            Analytics.track(.friendsOpened)
        }
    }

    // MARK: - Loaded

    private func loadedContent(data: FriendsData) -> some View {
        let isSearching = !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {

                // Soft push-permission banner when user has denied notifications (PRD §5).
                if notificationsService.authorizationStatus == .denied {
                    SoftPermissionBanner()
                }

                FriendsHeroBar(onQRTap: {})

                FriendsSubTabs(selected: $selectedTab)

                FriendsSearchBar(text: $viewModel.searchText)

                if isSearching {
                    searchResultsSection
                } else {
                    mainSections(data: data)
                }

                Spacer(minLength: 32)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Search results section

    @ViewBuilder
    private var searchResultsSection: some View {
        if viewModel.isSearching {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
        } else if let err = viewModel.searchError {
            Text(err)
                .font(.sfPro(14))
                .foregroundStyle(Color.apolloCaption)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
                .multilineTextAlignment(.center)
        } else if viewModel.searchResults.isEmpty {
            Text("No users found")
                .font(.sfPro(14))
                .foregroundStyle(Color.apolloCaption)
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
        } else {
            FriendsSectionHeader(title: "Results")

            ForEach(viewModel.searchResults) { result in
                SearchResultRow(
                    result: result,
                    onAdd: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            viewModel.addFromSearch(result)
                        }
                    },
                    onAccept: { fid in
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.acceptFromSearch(result, friendshipID: fid)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Main sections (non-search)

    @ViewBuilder
    private func mainSections(data: FriendsData) -> some View {
        // REQUESTS — hidden when empty
        if !data.requests.isEmpty {
            FriendsSectionHeader(title: "Requests")

            ForEach(data.requests) { request in
                FriendRequestRow(
                    request: request,
                    onAccept: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.acceptRequest(request)
                        }
                    },
                    onDecline: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.declineRequest(request)
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }

        // RECOMMENDED — hidden when empty
        if !data.recommended.isEmpty {
            FriendsSectionHeader(title: "Recommended")

            ForEach(data.recommended) { user in
                RecommendedFriendRow(
                    user: user,
                    onAdd: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            viewModel.addRecommended(user)
                        }
                    },
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            viewModel.dismissRecommended(user)
                        }
                    }
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                // Load next 10 — deferred for v1
            } label: {
                Text("Tap to Show More")
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloTabInactive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
        }

        // INVITE CARD (always shown so user can copy/share their code)
        InviteCard(
            affiliateCode: viewModel.affiliateCode,
            onCopy: { viewModel.trackInviteCodeCopied() },
            onShare: { viewModel.trackInviteCodeShared() }
        )

        // INVITE FRIENDS — hidden when contacts empty (contacts is [] for hackathon)
        if !data.contacts.isEmpty {
            FriendsSectionHeader(title: "Invite Friends")

            ForEach(data.contacts) { contact in
                InviteContactRow(contact: contact, affiliateCode: viewModel.affiliateCode)
            }
        }
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            FriendsHeroBar()
            FriendsSubTabs(selected: .constant(.friends))
            FriendsSearchBar(text: .constant(""))

            ForEach(0..<5, id: \.self) { _ in
                skeletonRow
            }
        }
    }

    private var skeletonRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.apolloSkeleton)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 80, height: 10)
            }

            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.apolloSkeleton)
                .frame(width: 56, height: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Error

    private func errorContent(message: String) -> some View {
        VStack(spacing: 0) {
            FriendsHeroBar()
            FriendsSubTabs(selected: .constant(.friends))
            FriendsSearchBar(text: .constant(""))

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
            .padding(.top, 16)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FriendsView(currentUser: nil)
        .preferredColorScheme(.dark)
}
