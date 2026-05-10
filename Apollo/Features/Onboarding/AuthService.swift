//
//  AuthService.swift
//  Apollo
//
//  Single source of truth for all three Supabase auth sign-in paths.
//  Shared across AppleSignInButtonView, GoogleSignInButtonView, and
//  PhoneEntryView via @StateObject / @ObservedObject.
//
//  ─── EXTERNAL SETUP REQUIRED ─────────────────────────────────────────────────
//  The Swift code here is complete, but the following external steps MUST be
//  done before any sign-in will succeed at runtime:
//
//  1. APPLE — Supabase dashboard:
//     https://supabase.com/dashboard/project/milyuxhpruafrxkuhcxn/auth/providers
//     → Apple → Enable → paste your App Service ID and Team ID.
//     Also add your Apple private key (p8 file) and Key ID.
//     CRITICAL: in "Authorized Client IDs" add the iOS bundle id
//     `DariusEhsani.Apollo`, otherwise native ID-token sign-in is rejected.
//
//  2. APPLE — Apple Developer portal:
//     Register a Service ID (Identifiers → Service IDs) with Sign In with Apple
//     enabled. Set the Return URL to:
//       https://milyuxhpruafrxkuhcxn.supabase.co/auth/v1/callback
//     In Xcode, Signing & Capabilities → ensure "Sign in with Apple" capability
//     is present (the Apollo.entitlements file added here enables this).
//
//  3. GOOGLE — Supabase dashboard:
//     Same auth/providers page → Google → Enable → paste your OAuth Client ID
//     and Client Secret from Google Cloud Console.
//     Authorized redirect URI in Google Cloud: same callback URL as above.
//     Note: create a Web application OAuth client in Google Cloud Console
//     (not an iOS client) because Supabase uses its own server-side callback.
//     Then in Supabase → Auth → URL Configuration → Redirect URLs, add:
//       DariusEhsani.Apollo://auth/callback
//
//  4. PHONE — Supabase dashboard:
//     Auth → Providers → Phone → Enable → configure Twilio / MessageBird /
//     Vonage as the SMS provider and enter the required API credentials.
//
//  Once all four steps are done, sign-in calls below will create real rows in
//  auth.users and fire the on_auth_user_created trigger that populates
//  public.users.
//  ─────────────────────────────────────────────────────────────────────────────

import Auth
import Combine
import Foundation
import Supabase

@MainActor
final class AuthService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Apple

    /// Call with the raw identity token string and the unhashed nonce used to
    /// build the ASAuthorizationAppleIDRequest. Supabase will verify the nonce
    /// hash against what was embedded in the Apple JWT.
    func signInWithApple(idToken: String, rawNonce: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: rawNonce
            )
        )
    }

    // MARK: - Google

    /// Opens an ASWebAuthenticationSession managed internally by the Supabase
    /// Swift SDK. The redirectTo URL uses the app's custom URL scheme
    /// (registered in Apollo/Info.plist as CFBundleURLTypes) so the OS hands
    /// control back to the app after Google returns the OAuth code, and the
    /// SDK exchanges the code for a session automatically.
    func signInWithGoogle() async throws {
        isLoading = true
        defer { isLoading = false }
        try await supabase.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "DariusEhsani.Apollo://auth/callback")
        )
    }

    // MARK: - Phone OTP

    /// Sends an SMS OTP to the given E.164 phone number (e.g. "+15555550100").
    /// Does NOT sign the user in — the caller must follow up with
    /// `verifyOTP(phone:code:)` once the user enters the 6-digit code.
    func signInWithPhone(phone: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await supabase.auth.signInWithOTP(phone: phone)
    }

    /// Verifies the SMS OTP code the user typed on the OTP screen. On success
    /// Supabase persists the resulting session via its built-in storage.
    func verifyOTP(phone: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }
        try await supabase.auth.verifyOTP(
            phone: phone,
            token: code,
            type: .sms
        )
    }

    // MARK: - Session

    /// Returns the currently persisted session, if any. Used by the app's
    /// SessionStore at launch to decide whether to show RootTabView or
    /// OnboardingFlow without flashing the wrong root.
    func currentSession() async -> Session? {
        try? await supabase.auth.session
    }

    // MARK: - Error helpers

    func clearError() {
        errorMessage = nil
    }

    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
    }
}
