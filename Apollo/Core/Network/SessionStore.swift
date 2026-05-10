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
import UIKit

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var isBootstrapping: Bool = true
    @Published private(set) var currentUser: CurrentUser?
    /// Pre-decoded, circle-masked UIImage of the current user's avatar, sized
    /// for the tab bar (used by RootTabView's profile tabItem). Nil when
    /// avatar URL is missing or download is in flight. Necessary because
    /// SwiftUI `.tabItem` icons must be plain `Image(...)`-convertible —
    /// async views like KFImage break the tab bar layout.
    @Published private(set) var currentUserAvatarImage: UIImage?

    private var listenerTask: Task<Void, Never>?
    private var refreshCancellable: AnyCancellable?
    private var lastFetchedAvatarURL: URL?

    init() {
        listenerTask = Task { [weak self] in
            await self?.bootstrap()
        }
        refreshCancellable = NotificationCenter.default
            .publisher(for: .apolloProfileShouldRefresh)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, let userID = self.session?.user.id else { return }
                Task { await self.loadCurrentUser(for: userID) }
            }
    }

    deinit {
        listenerTask?.cancel()
        refreshCancellable?.cancel()
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
            let url = row.avatar_url.flatMap(URL.init(string:))
            self.currentUser = CurrentUser(
                id: row.id,
                username: row.username,
                avatarURL: url
            )
            await refreshAvatarImage(for: url)
        } catch {
            // Leave currentUser unchanged on transient failure; auth still works.
        }
    }

    /// Downloads the avatar URL into a UIImage masked to a circle, suitable
    /// for use in `.tabItem { Image(uiImage:) }`. Re-runs whenever the URL
    /// changes; clears the image when URL becomes nil.
    private func refreshAvatarImage(for url: URL?) async {
        guard let url else {
            self.currentUserAvatarImage = nil
            self.lastFetchedAvatarURL = nil
            return
        }
        if url == lastFetchedAvatarURL && currentUserAvatarImage != nil { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let raw = UIImage(data: data) else {
                // #region agent log
                DebugFileLog.log("H1", "SessionStore.refreshAvatarImage", "decode FAILED", [
                    "byteCount": data.count,
                    "url": url.absoluteString,
                ])
                // #endregion
                return
            }
            // Tab bar icons are 25×25 points. We render at the device's native
            // displa   y scale so the bitmap is crisp, but the resulting UIImage's
            // point-size is what UITabBarItem uses for layout.
            let displayScale = UITraitCollection.current.displayScale > 0
                ? UITraitCollection.current.displayScale
                : 3.0
            let masked = await Task.detached(priority: .userInitiated) {
                Self.circleMasked(raw, pointSize: 25, scale: displayScale)
            }.value
            // Force .alwaysOriginal — without this iOS treats the icon as a
            // template image and tints it with the tab bar's selection color
            // (resulting in a solid-colored circle instead of the avatar).
            self.currentUserAvatarImage = masked.withRenderingMode(.alwaysOriginal)
            self.lastFetchedAvatarURL = url
            // #region agent log
            DebugFileLog.log("H1", "SessionStore.refreshAvatarImage", "avatar masked & cached", [
                "url": url.absoluteString,
                "maskedSize": "\(masked.size.width)x\(masked.size.height)",
            ])
            // #endregion
        } catch {
            // Best-effort; tab bar will fall back to placeholder.
            // #region agent log
            DebugFileLog.log("H1", "SessionStore.refreshAvatarImage", "download FAILED", [
                "url": url.absoluteString,
                "errDesc": (error as NSError).localizedDescription,
            ])
            // #endregion
        }
    }

    nonisolated private static func circleMasked(_ image: UIImage, pointSize: CGFloat, scale: CGFloat) -> UIImage {
        let pointRect = CGSize(width: pointSize, height: pointSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: pointRect, format: format)
        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: pointRect)
            UIBezierPath(ovalIn: rect).addClip()
            let srcSize = image.size
            let aspectFill = max(pointRect.width / srcSize.width, pointRect.height / srcSize.height)
            let drawSize = CGSize(width: srcSize.width * aspectFill, height: srcSize.height * aspectFill)
            let drawRect = CGRect(
                x: (pointRect.width - drawSize.width) / 2,
                y: (pointRect.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            image.draw(in: drawRect)
        }
    }
}
