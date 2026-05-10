//
//  ApolloApp.swift
//  Apollo
//
//  Created by Darius Ehsani on 5/9/26.
//
//  Root scene. The "are we logged in?" decision is delegated entirely to
//  SessionStore, which observes supabase.auth.authStateChanges. Sign in,
//  sign out, and token refresh all flow through the same listener, so the
//  app's root view always reflects the real Supabase session.
//

import SwiftUI

@main
struct ApolloApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var sessionStore = SessionStore()
    @StateObject private var notificationsService = NotificationsService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if sessionStore.isBootstrapping {
                    Color.apolloBackground.ignoresSafeArea()
                } else if sessionStore.session != nil {
                    RootTabView()
                } else {
                    OnboardingFlow {
                        // No-op: SessionStore's authStateChanges listener will
                        // flip the root automatically once Supabase reports a
                        // signed-in session. Kept for backwards compatibility
                        // with screens that still call onSignedIn.
                    }
                }
            }
            .environmentObject(sessionStore)
            .environmentObject(notificationsService)
            .preferredColorScheme(.dark)
            .onOpenURL { url in
                DeepLinkRouter.shared.handle(url: url)
            }
            .onChange(of: sessionStore.currentUser?.id) { _, newID in
                if let id = newID {
                    notificationsService.start(currentUserID: id)
                } else {
                    notificationsService.stop()
                }
            }
        }
    }
}
