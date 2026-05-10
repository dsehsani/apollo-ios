//
//  DeepLinkRouter.swift
//  Apollo
//
//  Decodes apollo:// deep links and routes them to the right tab / post.
//  Consumed by RootTabView (tab switching) and FeedView (post navigation).
//  Called from UNUserNotificationCenterDelegate and .onOpenURL.
//

import Combine
import Foundation
import SwiftUI

// MARK: - DeepLinkRouter

@MainActor
final class DeepLinkRouter: ObservableObject {
    static let shared = DeepLinkRouter()
    private init() {}

    /// The tab that should be activated. Cleared after consumption.
    @Published var targetTab: RootTabSelection?
    /// Post ID to scroll/push to within FeedView. Cleared after consumption.
    @Published var targetPostID: UUID?
    /// Whether the comments sheet should open for targetPostID.
    @Published var openComments: Bool = false

    /// Handle a notification's userInfo dictionary (from UNUserNotificationCenterDelegate).
    func handle(_ userInfo: [AnyHashable: Any]) {
        guard let deepLinkStr = userInfo["deep_link"] as? String else { return }
        route(urlString: deepLinkStr, notifType: userInfo["type"] as? String)
    }

    /// Handle an apollo:// URL (from .onOpenURL or scene delegate).
    func handle(url: URL) {
        route(urlString: url.absoluteString, notifType: nil)
    }

    private func route(urlString: String, notifType: String?) {
        let deepLink = NotificationDeepLink.from(urlString: urlString)

        switch deepLink {
        case .feedPost(let postID, let comments):
            targetTab = .feed
            targetPostID = postID
            openComments = comments

            Analytics.track(.notificationTapped, [
                "type": notifType ?? "unknown",
                "deep_link": urlString,
            ])

        case .feed:
            targetTab = .feed
            Analytics.track(.notificationTapped, ["type": notifType ?? "unknown", "deep_link": urlString])

        case .friends:
            targetTab = .friends
            Analytics.track(.notificationTapped, ["type": notifType ?? "unknown", "deep_link": urlString])

        case .north:
            targetTab = .north
            Analytics.track(.notificationTapped, ["type": notifType ?? "unknown", "deep_link": urlString])

        case .notifications:
            targetTab = .feed   // Notifications center is pushed from Feed.
            Analytics.track(.notificationTapped, ["type": notifType ?? "unknown", "deep_link": urlString])
        }
    }
}

// MARK: - RootTabSelection (mirrors RootTabView.TabSelection)
// Defined here to avoid a circular dependency. RootTabView maps from this.

enum RootTabSelection: Hashable {
    case feed, friends, north, profile
}
