//
//  SupabaseNotificationsRepository.swift
//  Apollo
//
//  Supabase-backed NotificationsRepositoryProtocol implementation.
//  Queries: notifications, notification_prefs.
//  Realtime: INSERT channel on notifications filtered by user_id.
//

import Foundation
import Supabase

// MARK: - Private Decodable rows

private struct NotificationDBRow: Decodable {
    let id: UUID
    let type: String
    let actor_id: UUID?
    let post_id: UUID?
    let comment_id: UUID?
    let metadata: NotificationPayload?
    let read_at: String?
    let created_at: String
    let actor: ActorEmbed?

    struct NotificationPayload: Decodable {
        let title: String?
        let body: String?
        let deep_link: String?
    }

    struct ActorEmbed: Decodable {
        let id: UUID?
        let display_name: String?
        let username: String?
        let avatar_url: String?
    }
}

private struct NotificationPrefsRow: Decodable {
    let social_enabled: Bool
    let habit_enabled: Bool
    let milestone_enabled: Bool
    let north_enabled: Bool
    let quiet_start: String
    let quiet_end: String
    let timezone: String
}

private struct UnreadCountRow: Decodable {
    let count: Int
}

// MARK: - SupabaseNotificationsRepository

final class SupabaseNotificationsRepository: NotificationsRepositoryProtocol, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // MARK: fetchRecent

    func fetchRecent(limit: Int) async throws -> [AppNotification] {
        do {
            let rows: [NotificationDBRow] = try await supabase
                .from("notifications")
                .select("""
                    id, type, actor_id, post_id, comment_id, metadata, read_at, created_at,
                    actor:users!notifications_actor_id_fkey(id, display_name, username, avatar_url)
                """)
                .eq("user_id", value: currentUserID)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value

            return rows.compactMap { mapRow($0) }
        } catch {
            // #region agent log
            print("[debug-18c33d][A-D] fetchRecent error: \(error)")
            print("[debug-18c33d][A-D] fetchRecent error type: \(type(of: error))")
            // #endregion
            throw NotificationsRepositoryError.network
        }
    }

    // MARK: unreadCount

    func unreadCount() async throws -> Int {
        do {
            let response = try await supabase
                .from("notifications")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: currentUserID)
                .is("read_at", value: Bool?.none)
                .execute()

            return response.count ?? 0
        } catch {
            // #region agent log
            print("[debug-18c33d][A-D] unreadCount error: \(error)")
            // #endregion
            throw NotificationsRepositoryError.network
        }
    }

    // MARK: markAllRead

    func markAllRead() async throws {
        do {
            try await supabase
                .from("notifications")
                .update(["read_at": ISO8601DateFormatter().string(from: Date())])
                .eq("user_id", value: currentUserID)
                .is("read_at", value: Bool?.none)
                .execute()
        } catch {
            throw NotificationsRepositoryError.network
        }
    }

    // MARK: markRead

    func markRead(id: UUID) async throws {
        do {
            try await supabase
                .from("notifications")
                .update(["read_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: id)
                .eq("user_id", value: currentUserID)
                .execute()
        } catch {
            throw NotificationsRepositoryError.network
        }
    }

    // MARK: notificationStream (Realtime)

    func notificationStream() -> AsyncStream<AppNotification> {
        AsyncStream { continuation in
            Task {
                // #region agent log
                print("[debug-18c33d][E] notificationStream started for userID=\(currentUserID.uuidString)")
                // #endregion

                let channel = supabase.realtimeV2.channel(
                    "notifications:\(currentUserID.uuidString)"
                )

                let changes = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "notifications",
                    filter: .eq("user_id", value: currentUserID.uuidString)
                )

                await channel.subscribe()

                continuation.onTermination = { _ in
                    Task { await supabase.realtimeV2.removeChannel(channel) }
                }

                for await change in changes {
                    if let notif = decodeRealtimeRow(change.record) {
                        continuation.yield(notif)
                    }
                }
            }
        }
    }

    // MARK: fetchPreferences

    func fetchPreferences() async throws -> NotificationPrefs {
        do {
            let row: NotificationPrefsRow = try await supabase
                .from("notification_prefs")
                .select()
                .eq("user_id", value: currentUserID)
                .single()
                .execute()
                .value

            return NotificationPrefs(
                socialEnabled: row.social_enabled,
                habitEnabled: row.habit_enabled,
                milestoneEnabled: row.milestone_enabled,
                northEnabled: row.north_enabled,
                quietStart: row.quiet_start,
                quietEnd: row.quiet_end,
                timezone: row.timezone
            )
        } catch {
            return NotificationPrefs.default
        }
    }

    // MARK: updatePreferences

    func updatePreferences(_ prefs: NotificationPrefs) async throws {
        struct PrefsUpdate: Encodable {
            let user_id: String
            let social_enabled: Bool
            let habit_enabled: Bool
            let milestone_enabled: Bool
            let north_enabled: Bool
            let quiet_start: String
            let quiet_end: String
            let timezone: String
            let updated_at: String
        }
        let payload = PrefsUpdate(
            user_id:          currentUserID.uuidString,
            social_enabled:   prefs.socialEnabled,
            habit_enabled:    prefs.habitEnabled,
            milestone_enabled: prefs.milestoneEnabled,
            north_enabled:    prefs.northEnabled,
            quiet_start:      prefs.quietStart,
            quiet_end:        prefs.quietEnd,
            timezone:         prefs.timezone,
            updated_at:       ISO8601DateFormatter().string(from: Date())
        )
        do {
            try await supabase
                .from("notification_prefs")
                .upsert(payload, onConflict: "user_id")
                .execute()
        } catch {
            throw NotificationsRepositoryError.network
        }
    }

    // MARK: - Private helpers

    private func mapRow(_ row: NotificationDBRow) -> AppNotification? {
        let type = NotificationType(rawValue: row.type) ?? .unknown

        var actor: NotificationActor?
        if let a = row.actor, let username = a.username {
            actor = NotificationActor(
                id: a.id ?? UUID(),
                username: username,
                displayName: a.display_name,
                avatarURL: a.avatar_url.flatMap { URL(string: $0) }
            )
        }

        let copy = row.metadata?.body ?? row.metadata?.title ?? ""
        let deepLinkStr = row.metadata?.deep_link ?? "apollo://feed"
        let deepLink = NotificationDeepLink.from(urlString: deepLinkStr)

        let timestamp: Date
        let formatter = ISO8601DateFormatter()
        timestamp = formatter.date(from: row.created_at) ?? Date()

        return AppNotification(
            id: row.id,
            type: type,
            actor: actor,
            copy: copy,
            timestamp: timestamp,
            isRead: row.read_at != nil,
            deepLink: deepLink
        )
    }

    private func decodeRealtimeRow(_ record: [String: AnyJSON]) -> AppNotification? {
        guard
            let idStr = record["id"]?.stringValue,
            let id = UUID(uuidString: idStr),
            let typeStr = record["type"]?.stringValue
        else { return nil }

        let notifType = NotificationType(rawValue: typeStr) ?? .unknown

        var body = ""
        var deepLinkStr = "apollo://feed"

        // metadata column is a JSON object; decode manually from AnyJSON.
        if case .object(let metadataDict) = record["metadata"] {
            if case .string(let b) = metadataDict["body"] { body = b }
            if case .string(let d) = metadataDict["deep_link"] { deepLinkStr = d }
        }

        let deepLink = NotificationDeepLink.from(urlString: deepLinkStr)
        let isRead = record["read_at"]?.stringValue != nil

        return AppNotification(
            id: id,
            type: notifType,
            actor: nil,
            copy: body,
            timestamp: Date(),
            isRead: isRead,
            deepLink: deepLink
        )
    }
}

