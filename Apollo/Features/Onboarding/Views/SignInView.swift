//
//  SignInView.swift
//  Apollo
//
//  Post-onboarding sign-in screen. Freestyled in Apollo's visual language.
//  Presents three sign-in methods stacked vertically:
//    1. Sign in with Apple  (native ASAuthorizationAppleIDButton)
//    2. Continue with Google (custom white pill)
//    3. Continue with phone  (outlined dark pill → PhoneEntryView)
//
//  Successful Apple or Google sign-in calls onSignedIn() which flips
//  hasCompletedOnboarding in ApolloApp and replaces this flow with RootTabView.
//

import SwiftUI

struct SignInView: View {
    let onSignedIn: () -> Void
    let onUsePhone: () -> Void

    @StateObject private var authService = AuthService()
    @State private var showErrorToast = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Apollo wordmark – matches the header row on the other onboarding screens
                OnboardingApolloHeader()
                    .padding(.top, 65)

                Spacer()

                // Goudy headline
                Text("Sign in.")
                    .font(.goudyRegular(48))
                    .foregroundStyle(Color.apolloUsername)
                    .padding(.horizontal, 16)

                // Body
                Text("Pick how you want to sign in.")
                    .font(.sfPro(17, weight: .regular))
                    .foregroundStyle(Color.apolloCaption)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                Spacer()

                // Sign-in buttons
                VStack(spacing: 12) {
                    // Apple — native button, height enforced by frame
                    AppleSignInButtonView(authService: authService, onSignedIn: onSignedIn)
                        .frame(height: 44)
                        .padding(.horizontal, 16)

                    // Google
                    GoogleSignInButtonView(authService: authService, onSignedIn: onSignedIn)

                    // Phone
                    PhoneSignInButtonView(onTap: onUsePhone)
                }
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Loading overlay
            if authService.isLoading {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                ProgressView()
                    .tint(Color.apolloPrimaryText)
                    .scaleEffect(1.4)
            }

            // Error toast
            if showErrorToast, let msg = authService.errorMessage {
                VStack {
                    ErrorToast(message: msg, onDismiss: {
                        withAnimation { showErrorToast = false }
                        authService.clearError()
                    })
                    .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.25), value: showErrorToast)
            }
        }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil {
                withAnimation { showErrorToast = true }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SignInView(onSignedIn: {}, onUsePhone: {})
        .preferredColorScheme(.dark)
}
