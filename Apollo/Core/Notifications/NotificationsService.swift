//
//  NotificationsService.swift
//  Apollo
//
//  Central service for push notification permission, local habit reminders,
//  and the in-app unread count badge.
//
//  Lifecycle:
//   • ApolloApp owns it as @StateObject and injects it as .environmentObject.
//   • SessionStore observers fire it on sign-in to start listening.
//   • On post commit (apolloPostCommitted) it evaluates whether to show the
//     permission prompt.
//   • On feed refresh (apolloFeedShouldRefresh) it cancels pending habit reminders.
//

import Combine
import Foundation
import UIKit
import UserNotifications

// MARK: - PermissionContext

enum PermissionContext: String {
    case postFirstWin = "post_first_win"
    case settings     = "settings"
}

// MARK: - NotificationsService

@MainActor
final class NotificationsService: ObservableObject {
    /// App-wide singleton. ApolloApp uses this instance as @StateObject
    /// so the service is shared across environment and direct callers.
    static let shared = NotificationsService()

    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var unreadCount: Int = 0
    /// Set to true when the first-win prompt should be presented.
    @Published var shouldShowPermissionPrompt: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var realtimeTask: Task<Void, Never>?
    private var notificationsRepository: (any NotificationsRepositoryProtocol)?

    // MARK: - Lifecycle

    func start(currentUserID: UUID) {
        // #region agent log
        print("[debug-18c33d][A] NotificationsService.start() called for userID=\(currentUserID.uuidString)")
        // #endregion
        let repo = SupabaseNotificationsRepository(currentUserID: currentUserID)
        notificationsRepository = repo
        Task { await refreshUnreadCount() }
        subscribeRealtimeUnread(repo: repo)
        listenForPostCommit()
        listenForFeedRefresh()
        Task { await refreshStatus() }
    }

    func stop() {
        realtimeTask?.cancel()
        realtimeTask = nil
        notificationsRepository = nil
        cancellables.removeAll()
    }

    // MARK: - Authorization

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    /// Request authorization. Tracks analytics and, if granted, registers for remote.
    func requestAuthorization(context: PermissionContext) async -> Bool {
        Analytics.track(.notificationPermissionRequested, ["context": context.rawValue])

        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()

            if granted {
                Analytics.track(.notificationPermissionGranted)
                UIApplication.shared.registerForRemoteNotifications()
                scheduleHabitReminders()
            } else {
                Analytics.track(.notificationPermissionDenied)
            }
            return granted
        } catch {
            Analytics.track(.notificationPermissionDenied)
            return false
        }
    }

    // MARK: - Local habit reminders

    /// Schedules the 8pm "Win every day." and 11pm "Don't break it." local reminders.
    /// Safe to call multiple times — existing identifiers are replaced.
    func scheduleHabitReminders() {
        let center = UNUserNotificationCenter.current()

        let eightPm = makeHabitRequest(
            identifier: "apollo.habit.eight_pm",
            hour: 20, minute: 0,
            title: "Win every day.",
            body: "You haven't posted today."
        )
        let elevenPm = makeHabitRequest(
            identifier: "apollo.habit.eleven_pm",
            hour: 23, minute: 0,
            title: "Don't break it.",
            body: "Keep your streak alive."
        )

        center.add(eightPm)  { if let e = $0 { print("[NotificationsService] 8pm schedule error: \(e)") } }
        center.add(elevenPm) { if let e = $0 { print("[NotificationsService] 11pm schedule error: \(e)") } }
    }

    /// Cancels today's "haven't posted" local reminders when the user posts (PRD §6 AC3).
    func cancelHabitRemindersForToday() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [
                "apollo.habit.eight_pm",
                "apollo.habit.eleven_pm",
            ])
    }

    /// Schedule a specific win reminder (delegated from WinDetailsViewModel).
    func scheduleWinReminder(winID: UUID, name: String, time: Date, repeat schedule: WinReminderRepeat) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = name
        content.body  = "Time to win."
        content.sound = .default

        var components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger: UNNotificationTrigger

        switch schedule {
        case .daily:
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .weekly:
            components.weekday = Calendar.current.component(.weekday, from: Date())
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        case .once:
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: "apollo.win.\(winID.uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { if let e = $0 { print("[NotificationsService] win reminder error: \(e)") } }
    }

    func cancelWinReminder(winID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["apollo.win.\(winID.uuidString)"])
    }

    // MARK: - Unread count

    func refreshUnreadCount() async {
        guard let repo = notificationsRepository else { return }
        if let count = try? await repo.unreadCount() {
            unreadCount = count
        }
    }

    // MARK: - Private

    private func subscribeRealtimeUnread(repo: any NotificationsRepositoryProtocol) {
        realtimeTask?.cancel()
        realtimeTask = Task {
            for await _ in repo.notificationStream() {
                await refreshUnreadCount()
            }
        }
    }

    private func listenForPostCommit() {
        NotificationCenter.default
            .publisher(for: .apolloPostCommitted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let self else { return }
                let totalWins = note.userInfo?["totalWins"] as? Int ?? 0
                cancelHabitRemindersForToday()
                if totalWins == 1 && !UserDefaults.standard.bool(forKey: "apollo.hasShownPushPrompt") {
                    shouldShowPermissionPrompt = true
                }
            }
            .store(in: &cancellables)
    }

    private func listenForFeedRefresh() {
        NotificationCenter.default
            .publisher(for: .apolloFeedShouldRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.cancelHabitRemindersForToday() }
            .store(in: &cancellables)
    }

    private func makeHabitRequest(
        identifier: String,
        hour: Int,
        minute: Int,
        title: String,
        body: String
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute

        return UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        )
    }
}

// MARK: - WinReminderRepeat (bridge type for WinDetailsViewModel)

enum WinReminderRepeat {
    case daily, weekly, once
}
