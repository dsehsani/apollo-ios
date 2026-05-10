//
//  PushTokenRegistrar.swift
//  Apollo
//
//  Converts the raw APNs device token Data into a hex string and upserts it
//  into public.push_tokens. Called from AppDelegate after successful registration.
//

import Foundation
import Supabase

final class PushTokenRegistrar: @unchecked Sendable {
    static let shared = PushTokenRegistrar()
    private init() {}

    /// Call this from AppDelegate.application(_:didRegisterForRemoteNotificationsWithDeviceToken:).
    func upload(deviceToken: Data) async {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard let userID = supabase.auth.currentUser?.id else { return }

        do {
            try await supabase
                .from("push_tokens")
                .upsert(
                    [
                        "user_id":      userID.uuidString,
                        "token":        tokenString,
                        "platform":     "ios",
                        "last_seen_at": ISO8601DateFormatter().string(from: Date()),
                    ] as [String: String],
                    onConflict: "token"
                )
                .execute()
        } catch {
            // Non-fatal: token upload failure does not block the user.
            print("[PushTokenRegistrar] upload failed: \(error.localizedDescription)")
        }
    }
}
