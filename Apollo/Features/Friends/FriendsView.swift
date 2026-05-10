//
//  FriendsView.swift
//  Apollo
//
//  Friends screen (PRD §07). Shows "Connect" hero, Friends/Challenges sub-tabs,
//  search pill, Requests, Recommended, and Invite Friends sections.
//  Affiliate invite card deferred to a later iteration.
//

import SwiftUI

struct FriendsView: View {
    @State private var viewModel = FriendsViewModel()
    @State private var selectedTab: FriendsTab = .friends

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
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Loaded

    private func loadedContent(data: FriendsData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {

                FriendsHeroBar(onQRTap: {})

                FriendsSubTabs(selected: $selectedTab)

                FriendsSearchBar(text: $viewModel.searchText)

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

                // INVITE FRIENDS
                if !data.contacts.isEmpty {
                    FriendsSectionHeader(title: "Invite Friends")

                    ForEach(data.contacts) { contact in
                        InviteContactRow(contact: contact)
                    }
                }

                Spacer(minLength: 32)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable { await viewModel.refresh() }
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
    FriendsView()
        .preferredColorScheme(.dark)
}
