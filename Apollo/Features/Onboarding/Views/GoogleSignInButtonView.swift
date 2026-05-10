//
//  GoogleSignInButtonView.swift
//  Apollo
//
//  Custom Google sign-in button styled per Google brand guidelines:
//  white background, official multi-color G mark, dark label text.
//  Tap opens an ASWebAuthenticationSession managed by the Supabase SDK.
//

import SwiftUI

struct GoogleSignInButtonView: View {
    @ObservedObject var authService: AuthService
    let onSignedIn: () -> Void

    var body: some View {
        Button {
            Task {
                do {
                    try await authService.signInWithGoogle()
                    onSignedIn()
                } catch {
                    authService.handleError(error)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image("GoogleGLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)

                Text("Continue with Google")
                    .font(.sfPro(17, weight: .medium))
                    .foregroundStyle(Color(red: 0x1f/255, green: 0x1f/255, blue: 0x1f/255))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .disabled(authService.isLoading)
    }
}
