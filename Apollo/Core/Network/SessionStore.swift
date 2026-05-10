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
        // #region agent log
        let dbLog: (String, String, [String: Any]) -> Void = { hypothesisId, message, data in
            let ts = Date().timeIntervalSince1970
            var payload: [String: Any] = [
                "sessionId": "a1df08", "runId": "run1", "hypothesisId": hypothesisId,
                "location": "SessionStore.swift:bootstrap",
                "message": message, "timestamp": Int64(ts * 1000)
            ]
            payload.merge(data) { _, new in new }
            if let json = try? JSONSerialization.data(withJSONObject: payload),
               let line = String(data: json, encoding: .utf8) {
                let logPath = "/Volumes/Darius_SSD/Apollo/Apollo/.cursor/debug-a1df08.log"
                let entry = line + "\n"
                if let fh = FileHandle(forWritingAtPath: logPath) {
                    fh.seekToEndOfFile(); fh.write(entry.data(using: .utf8)!); try? fh.close()
                } else {
                    try? entry.write(toFile: logPath, atomically: false, encoding: .utf8)
                }
            }
        }
        dbLog("B", "bootstrap_called", ["objectId": "\(ObjectIdentifier(self).hashValue)"])
        // #endregion

        // Cold-launch session restore. If there is no saved session this just
        // returns nil — perfectly fine, we'll fall through to onboarding.
        // #region agent log
        dbLog("A", "before_session_fetch", [:])
        // #endregion
        if let existing = try? await supabase.auth.session {
            // #region agent log
            dbLog("A+D", "session_fetch_result", ["isExpired": existing.isExpired, "hasAccessToken": !existing.accessToken.isEmpty])
            // #endregion
            self.session = existing
        } else {
            // #region agent log
            dbLog("A", "session_fetch_result_nil", [:])
            // #endregion
        }
        self.isBootstrapping = false

        for await (event, session) in supabase.auth.authStateChanges {
            // #region agent log
            dbLog("B+C", "authStateChange", ["event": "\(event)", "hasSession": session != nil, "isExpired": session?.isExpired ?? false])
            // #endregion
            switch event {
            case .signedIn, .tokenRefreshed, .userUpdated, .initialSession:
                self.session = session
            case .signedOut, .userDeleted:
                self.session = nil
            default:
                self.session = session
            }
        }
    }
}
