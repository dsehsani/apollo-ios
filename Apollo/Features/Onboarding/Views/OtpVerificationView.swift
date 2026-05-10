//
//  OtpVerificationView.swift
//  Apollo
//
//  Second half of the phone sign-in flow: user enters the 6-digit code that
//  Supabase + Twilio just texted to their phone, and we call
//  supabase.auth.verifyOTP. On success the parent (OnboardingFlow) calls
//  onVerified() — by then SessionStore's authStateChanges listener has already
//  flipped the app's root to RootTabView, so this is essentially a no-op.
//
//  Visual language matches PhoneEntryView so the two feel like one flow.
//

import SwiftUI

struct OtpVerificationView: View {
    let phone: String
    let onVerified: () -> Void

    @StateObject private var authService = AuthService()
    @State private var code: String = ""
    @State private var showErrorToast = false
    @FocusState private var fieldFocused: Bool

    private var canSubmit: Bool {
        code.count == 6 && !authService.isLoading
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingApolloHeader()
                    .padding(.top, 65)

                Spacer()

                Text("Enter the\ncode.")
                    .font(.goudyRegular(48))
                    .foregroundStyle(Color.apolloUsername)
                    .padding(.horizontal, 16)

                Text("We texted a 6-digit code to \(phone).")
                    .font(.sfPro(17, weight: .regular))
                    .foregroundStyle(Color.apolloCaption)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                codeInputRow
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                Spacer()

                OnboardingPrimaryButton(title: "Verify") {
                    Task { await submitCode() }
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if authService.isLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
                ProgressView()
                    .tint(Color.apolloPrimaryText)
                    .scaleEffect(1.4)
            }

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
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { fieldFocused = true }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil { withAnimation { showErrorToast = true } }
        }
    }

    // MARK: - Code input

    private var codeInputRow: some View {
        TextField("123456", text: $code)
            .font(.sfPro(28, weight: .medium))
            .foregroundStyle(Color.apolloPrimaryText)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($fieldFocused)
            .tint(Color.apolloPrimaryText)
            .padding(.vertical, 14)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(Color.apolloStroke),
                alignment: .bottom
            )
            .onChange(of: code) { _, newValue in
                let digits = newValue.filter(\.isNumber)
                code = String(digits.prefix(6))
            }
    }

    // MARK: - Submit

    private func submitCode() async {
        guard canSubmit else { return }
        do {
            try await authService.verifyOTP(phone: phone, code: code)
            onVerified()
        } catch {
            authService.handleError(error)
        }
    }
}

#Preview {
    OtpVerificationView(phone: "+15555550100", onVerified: {})
        .preferredColorScheme(.dark)
}
