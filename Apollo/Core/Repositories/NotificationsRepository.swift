//
//  NotificationsRepository.swift
//  Apollo
//
//  Protocol + mock for the notifications data layer.
//

import Foundation

// MARK: - Protocol

protocol NotificationsRepositoryProtocol: Sendable {
    /// Fetch the 50 most recent notifications for the current user.
    func fetchRecent(limit: Int) async throws -> [AppNotification]
    /// Count of unread notifications.
    func unreadCount() async throws -> Int
    /// Mark all notifications as read.
    func markAllRead() async throws
    /// Mark a single notification as read.
    func markRead(id: UUID) async throws
    /// Live stream of new notifications as they arrive (Realtime INSERT).
    func notificationStream() -> AsyncStream<AppNotification>
    /// Fetch the user's notification preferences.
    func fetchPreferences() async throws -> NotificationPrefs
    /// Persist updated notification preferences.
    func updatePreferences(_ prefs: NotificationPrefs) async throws
}

// MARK: - Mock (previews / tests)

final class MockNotificationsRepository: NotificationsRepositoryProtocol, @unchecked Sendable {
    var mockNotifications: [AppNotification] = [
        AppNotification(
            id: UUID(),
            type: .reaction,
            actor: NotificationActor(id: UUID(), username: "jayden", displayName: "Jayden Betts", avatarURL: nil),
            copy: "Jayden Betts sent you a 👑",
            timestamp: Date().addingTimeInterval(-300),
            isRead: false,
            deepLink: .feed
        ),
        AppNotification(
            id: UUID(),
            type: .friendAccept,
            actor: NotificationActor(id: UUID(), username: "rildy", displayName: "Rildy", avatarURL: nil),
            copy: "You and Rildy are now friends on Apollo.",
            timestamp: Date().addingTimeInterval(-3600),
            isRead: true,
            deepLink: .friends
        ),
    ]

    var mockUnreadCount = 1
    var mockPrefs = NotificationPrefs.default

    func fetchRecent(limit: Int) async throws -> [AppNotification] { mockNotifications }
    func unreadCount() async throws -> Int { mockUnreadCount }
    func markAllRead() async throws {
        for i in mockNotifications.indices { mockNotifications[i].isRead = true }
        mockUnreadCount = 0
    }
    func markRead(id: UUID) async throws {
        if let i = mockNotifications.firstIndex(where: { $0.id == id }) {
            mockNotifications[i].isRead = true
        }
    }
    func notificationStream() -> AsyncStream<AppNotification> {
        AsyncStream { $0.finish() }
    }
    func fetchPreferences() async throws -> NotificationPrefs { mockPrefs }
    func updatePreferences(_ prefs: NotificationPrefs) async throws { mockPrefs = prefs }
}
