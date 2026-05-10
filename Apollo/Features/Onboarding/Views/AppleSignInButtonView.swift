//
//  AppleSignInButtonView.swift
//  Apollo
//
//  UIViewRepresentable wrapper around ASAuthorizationAppleIDButton that handles
//  the full Sign In with Apple flow:
//    1. Generates a random raw nonce and its SHA-256 hash
//    2. Creates an ASAuthorizationAppleIDRequest with .fullName and .email scopes
//    3. Presents ASAuthorizationController
//    4. On success, calls AuthService.signInWithApple(idToken:rawNonce:)
//    5. On completion, calls onSignedIn() so the SignInView can dismiss / let
//       the SessionStore auth listener flip the app's root.
//
//  The view receives the parent SignInView's AuthService so loading + error
//  state surface through the shared overlay/toast (no second AuthService).
//

import Combine
import SwiftUI
import AuthenticationServices
import CryptoKit

struct AppleSignInButtonView: View {
    @ObservedObject var authService: AuthService
    let onSignedIn: () -> Void

    @StateObject private var coordinator = AppleSignInCoordinator()

    var body: some View {
        AppleButtonRepresentable(coordinator: coordinator)
            .frame(height: 44)
            .cornerRadius(10)
            .onAppear {
                coordinator.bind(authService: authService, onSignedIn: onSignedIn)
            }
    }
}

// MARK: - UIViewRepresentable

private struct AppleButtonRepresentable: UIViewRepresentable {
    let coordinator: AppleSignInCoordinator

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.addTarget(coordinator, action: #selector(AppleSignInCoordinator.handleTap), for: .touchUpInside)
        button.cornerRadius = 10
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}

// MARK: - Coordinator

@MainActor
final class AppleSignInCoordinator: NSObject, ObservableObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private weak var authService: AuthService?
    private var onSignedIn: (() -> Void)?
    private var rawNonce: String?

    func bind(authService: AuthService, onSignedIn: @escaping () -> Void) {
        self.authService = authService
        self.onSignedIn = onSignedIn
    }

    @objc func handleTap() {
        let nonce = randomNonce()
        rawNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        authService?.isLoading = true

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    // MARK: ASAuthorizationControllerDelegate

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = rawNonce,
                let service = authService
            else {
                authService?.isLoading = false
                authService?.handleError(AuthServiceError.missingToken)
                return
            }

            do {
                try await service.signInWithApple(idToken: idToken, rawNonce: nonce)
                onSignedIn?()
            } catch {
                service.handleError(error)
            }
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            authService?.isLoading = false
            // ASAuthorizationError.canceled (code 1001) is expected when the
            // user taps Cancel; don't surface that as an error.
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                authService?.handleError(error)
            }
        }
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // ASAuthorizationController always calls this on the main thread,
        // so assumeIsolated is safe and avoids the @MainActor isolation errors.
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            return active?.keyWindow ?? UIWindow(frame: .zero)
        }
    }

    // MARK: - Crypto helpers

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        return randomBytes.map { String(format: "%02x", $0) }.joined()
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum AuthServiceError: LocalizedError {
    case missingToken
    var errorDescription: String? { "Unable to retrieve identity token from Apple." }
}
