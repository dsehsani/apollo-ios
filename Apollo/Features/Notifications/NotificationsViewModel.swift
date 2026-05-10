//
//  NotificationsViewModel.swift
//  Apollo
//
//  @Observable ViewModel for the in-app Notification Center (PRD §3).
//

import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class NotificationsViewModel {

    enum Phase {
        case loading
        case loaded([AppNotification])
        case error(String)
    }

    private(set) var phase: Phase = .loading

    private let repository: any NotificationsRepositoryProtocol
    private var realtimeTask: Task<Void, Never>?

    // MARK: - Init

    init(currentUserID: UUID) {
        self.repository = SupabaseNotificationsRepository(currentUserID: currentUserID)
    }

    init(repository: any NotificationsRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Lifecycle

    func onAppear(notificationsService: NotificationsService) async {
        await load()
        await markAllRead(notificationsService: notificationsService)
        subscribeRealtime()

        Analytics.track(.notificationCenterOpened, [
            "unread_count": unreadCount,
        ])
    }

    func onDisappear() {
        realtimeTask?.cancel()
        realtimeTask = nil
    }

    // MARK: - Data

    func load() async {
        phase = .loading
        do {
            let notifications = try await repository.fetchRecent(limit: 50)
            phase = .loaded(notifications)
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func retry() async {
        await load()
    }

    // MARK: - Mark read

    private func markAllRead(notificationsService: NotificationsService) async {
        try? await repository.markAllRead()
        // Reflect the zero-unread state immediately in the badge.
        notificationsService.unreadCount = 0
        // Clear app icon badge.
        try? await UNUserNotificationCenter.current().setBadgeCount(0)

        // Update local state to show rows as read.
        if case .loaded(let items) = phase {
            phase = .loaded(items.map { n in
                var m = n; m.isRead = true; return m
            })
        }
    }

    // MARK: - Realtime

    private func subscribeRealtime() {
        realtimeTask?.cancel()
        realtimeTask = Task {
            for await newNotif in repository.notificationStream() {
                guard !Task.isCancelled else { break }
                if case .loaded(var items) = phase {
                    items.insert(newNotif, at: 0)
                    if items.count > 50 { items = Array(items.prefix(50)) }
                    phase = .loaded(items)
                }
            }
        }
    }

    // MARK: - Helpers

    private var unreadCount: Int {
        guard case .loaded(let items) = phase else { return 0 }
        return items.filter { !$0.isRead }.count
    }
}

