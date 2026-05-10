//
//  NotificationsView.swift
//  Apollo
//
//  In-app Notification Center — pushed from Feed's bell icon.
//
//  Spec (PRD §3):
//   • Header: "Notifications" — Goudy italic, top center
//   • Rows: NotificationRow × 50 most recent
//   • Empty state: "Nothing yet. Post your first win." — Goudy italic centered
//   • Mark all read on open
//   • Max 50, 30-day retention (enforced server-side)
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var notificationsService: NotificationsService
    @State private var viewModel: NotificationsViewModel

    let currentUser: CurrentUser?

    init(currentUser: CurrentUser?) {
        self.currentUser = currentUser
        let userID = currentUser?.id ?? UUID()
        _viewModel = State(initialValue: NotificationsViewModel(currentUserID: userID))
    }

    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()

            switch viewModel.phase {
            case .loading:
                loadingView
            case .loaded(let notifications):
                if notifications.isEmpty {
                    emptyState
                } else {
                    notificationList(notifications)
                }
            case .error(let message):
                errorView(message: message)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Notifications")
                    .font(.goudyItalic(20))
                    .foregroundStyle(Color.apolloPrimaryText)
            }
        }
        .task {
            await viewModel.onAppear(notificationsService: notificationsService)
        }
        .onDisappear {
            viewModel.onDisappear()
        }
    }

    // MARK: - Loaded list

    private func notificationList(_ notifications: [AppNotification]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(notifications) { notification in
                NotificationRow(notification: notification) {
                    handleTap(notification)
                }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("Nothing yet. Post your first win.")
                .font(.goudyItalic(18))
                .foregroundStyle(Color.apolloMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel("No notifications yet.")
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { _ in
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.apolloSkeleton)
                        .frame(width: 36, height: 36)
                        .padding(.leading, 30)
                    VStack(alignment: .leading, spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.apolloSkeleton)
                            .frame(width: 200, height: 12)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.apolloSkeleton)
                            .frame(width: 60, height: 10)
                    }
                    .padding(.leading, 10)
                    Spacer()
                }
                .frame(height: 56)
            }
        }
        .redacted(reason: .placeholder)
    }

    // MARK: - Error

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Couldn't load notifications.")
                .font(.sfPro(14))
                .foregroundStyle(Color.apolloCaption)
            Button("Retry") {
                Task { await viewModel.retry() }
            }
            .font(.sfPro(14, weight: .medium))
            .foregroundStyle(Color.apolloPrimaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tap handling

    private func handleTap(_ notification: AppNotification) {
        switch notification.deepLink {
        case .feedPost(let postID, let openComments):
            DeepLinkRouter.shared.targetPostID = postID
            DeepLinkRouter.shared.openComments = openComments
            DeepLinkRouter.shared.targetTab = .feed
        case .feed:
            DeepLinkRouter.shared.targetTab = .feed
        case .friends:
            DeepLinkRouter.shared.targetTab = .friends
        case .north:
            DeepLinkRouter.shared.targetTab = .north
        case .notifications:
            break
        }

        Analytics.track(.notificationTapped, [
            "type": notification.type.rawValue,
            "deep_link": notification.deepLink.debugDescription,
        ])
    }
}

// MARK: - NotificationDeepLink debugDescription

private extension NotificationDeepLink {
    var debugDescription: String {
        switch self {
        case .feedPost(let id, _): return "apollo://feed/post/\(id)"
        case .feed:           return "apollo://feed"
        case .friends:        return "apollo://friends"
        case .north:          return "apollo://north"
        case .notifications:  return "apollo://notifications"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView(currentUser: nil)
            .environmentObject(NotificationsService())
    }
    .preferredColorScheme(.dark)
}
