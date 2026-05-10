//
//  NotificationsModels.swift
//  Apollo
//
//  Domain models for the Notifications system (PRD §10-notification-system.md).
//

import Foundation

// MARK: - NotificationType

enum NotificationType: String, Codable, Sendable {
    case reaction         = "reaction"
    case comment          = "comment"
    case reply            = "reply"
    case friendRequest    = "friend_request"
    case friendAccept     = "friend_accept"
    case firstWinToday    = "first_win_today"
    case milestone7       = "milestone_7"
    case milestone30      = "milestone_30"
    case milestone100     = "milestone_100"
    case milestoneFriend7 = "milestone_friend_7"
    case habitNoPost      = "habit_no_post"
    case habitStreakBreak = "habit_streak_break"
    case winReminder      = "win_reminder"
    case northWeekly      = "north_weekly"
    case unknown          = "unknown"
}

// MARK: - NotificationActor

struct NotificationActor: Sendable, Hashable {
    let id: UUID
    let username: String
    let displayName: String?
    let avatarURL: URL?
}

// MARK: - NotificationDeepLink

enum NotificationDeepLink: Sendable, Hashable {
    case feedPost(postID: UUID, openComments: Bool)
    case feed
    case friends
    case north
    case notifications

    static func from(urlString: String) -> NotificationDeepLink {
        guard let url = URL(string: urlString),
              url.scheme == "apollo" else { return .feed }

        let host = url.host ?? ""
        let path = url.path

        switch host {
        case "feed":
            if path.hasPrefix("/post/"),
               let idStr = path.components(separatedBy: "/").dropFirst(2).first,
               let id = UUID(uuidString: idStr) {
                let openComments = url.query?.contains("openComments=1") == true
                return .feedPost(postID: id, openComments: openComments)
            }
            return .feed
        case "friends":
            return .friends
        case "north":
            return .north
        case "notifications":
            return .notifications
        default:
            return .feed
        }
    }
}

// MARK: - AppNotification

struct AppNotification: Sendable, Identifiable, Hashable {
    let id: UUID
    let type: NotificationType
    let actor: NotificationActor?
    /// Pre-built display text from the payload (title or body as appropriate for the list row).
    let copy: String
    let timestamp: Date
    var isRead: Bool
    let deepLink: NotificationDeepLink
}

// MARK: - NotificationPrefs

struct NotificationPrefs: Sendable, Hashable {
    var socialEnabled: Bool
    var habitEnabled: Bool
    var milestoneEnabled: Bool
    var northEnabled: Bool
    var quietStart: String   // "HH:MM"
    var quietEnd: String     // "HH:MM"
    var timezone: String

    static let `default` = NotificationPrefs(
        socialEnabled: true,
        habitEnabled: true,
        milestoneEnabled: true,
        northEnabled: true,
        quietStart: "22:00",
        quietEnd: "08:00",
        timezone: TimeZone.current.identifier
    )
}

// MARK: - Errors

enum NotificationsRepositoryError: Error, LocalizedError {
    case network
    case notFound
    case unknown

    var errorDescription: String? {
        switch self {
        case .network:  return "Couldn't load notifications."
        case .notFound: return "Notification not found."
        case .unknown:  return "An unexpected error occurred."
        }
    }
}
