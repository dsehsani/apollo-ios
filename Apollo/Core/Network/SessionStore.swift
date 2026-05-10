//
//  SessionStore.swift
//  Apollo
//
//  Reactive wrapper around supabase.auth that the app's root view watches to
//  decide whether to show OnboardingFlow or RootTabView.
//
//  Why this exists: per the auth spec the app must rely on Supabase's built-in
//  session management — no AppStorage flags, no manual UserDefaults / Keychain
//  token storage. The Supabase Swift SDK already persists the session in the
//  Keychain on its own; SessionStore just exposes the session as an
//  ObservableObject so SwiftUI can re-render when sign-in / sign-out happens.
//
//  Lifecycle:
//    1. init() kicks off a Task that
//       a. reads any existing session from the SDK (cold launch),
//       b. flips isBootstrapping → false so the splash dismisses,
//       c. iterates `supabase.auth.authStateChanges` forever, updating
//          self.session on every event.
//    2. Errors from the stream are swallowed — a missing session simply means
//       the user needs to sign in.
//

import Auth
import Combine
import Foundation
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isBootstrapping: Bool = true
    @Published private(set) var currentUser: CurrentUser?

    private var listenerTask: Task<Void, Never>?

    init() {
        listenerTask = Task { [weak self] in
            await self?.bootstrap()
        }
    }

    deinit {
        listenerTask?.cancel()
    }

    private func bootstrap() async {
        // Cold-launch session restore. If there is no saved session this just
        // returns nil — perfectly fine, we'll fall through to onboarding.
        if let existing = try? await supabase.auth.session {
            self.session = existing
            await loadCurrentUser(for: existing.user.id)
        }
        self.isBootstrapping = false

        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .signedIn, .tokenRefreshed, .userUpdated, .initialSession:
                self.session = session
                if let userID = session?.user.id {
                    await loadCurrentUser(for: userID)
                } else {
                    self.currentUser = nil
                }
            case .signedOut, .userDeleted:
                self.session = nil
                self.currentUser = nil
            default:
                self.session = session
            }
        }
    }

    private func loadCurrentUser(for userID: UUID) async {
        struct Row: Decodable { let id: UUID; let username: String; let avatar_url: String? }
        do {
            let row: Row = try await supabase
                .from("users")
                .select("id, username, avatar_url")
                .eq("id", value: userID)
                .single()
                .execute()
                .value
            self.currentUser = CurrentUser(
                id: row.id,
                username: row.username,
                avatarURL: row.avatar_url.flatMap(URL.init(string:))
            )
        } catch {
            // Leave currentUser unchanged on transient failure; auth still works.
        }
    }
}
