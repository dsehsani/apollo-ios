//
//  PhoneEntryView.swift
//  Apollo
//
//  Phone number entry screen. User types their number, taps Continue,
//  an OTP SMS is dispatched via Supabase Auth, and we navigate to the
//  OTP verification screen with the same E.164 string.
//
//  This screen does NOT flip the auth state — that happens after the user
//  enters the 6-digit code on OtpVerificationView and Supabase verifies it.
//

import SwiftUI

struct PhoneEntryView: View {
    let onCodeSent: (String) -> Void

    @StateObject private var authService = AuthService()

    // Country code defaults to US; user can type their own prefix inline.
    @State private var countryCode = "+1"
    @State private var phoneNumber = ""
    @State private var showErrorToast = false
    @FocusState private var fieldFocused: Bool

    private var e164Phone: String {
        // Strip any spaces or dashes the user might type
        let digits = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return countryCode + digits
    }

    private var canSubmit: Bool {
        phoneNumber.count >= 7 && !authService.isLoading
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                OnboardingApolloHeader()
                    .padding(.top, 65)

                Spacer()

                // Goudy headline
                Text("What's your\nnumber?")
                    .font(.goudyRegular(48))
                    .foregroundStyle(Color.apolloUsername)
                    .padding(.horizontal, 16)

                // Body
                Text("We'll text you a code to sign in.")
                    .font(.sfPro(17, weight: .regular))
                    .foregroundStyle(Color.apolloCaption)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                // Phone input row
                phoneInputRow
                    .padding(.horizontal, 16)
                    .padding(.top, 32)

                Spacer()

                // Continue CTA
                OnboardingPrimaryButton(title: "Continue") {
                    Task { await submitPhone() }
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.45)
                .padding(.bottom, 48)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Loading overlay
            if authService.isLoading {
                Color.black.opacity(0.45).ignoresSafeArea()
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
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { fieldFocused = true }
        .onChange(of: authService.errorMessage) { _, newValue in
            if newValue != nil { withAnimation { showErrorToast = true } }
        }
    }

    // MARK: - Phone input field

    private var phoneInputRow: some View {
        HStack(spacing: 8) {
            // Country code field (short, editable)
            TextField("+1", text: $countryCode)
                .font(.sfPro(17, weight: .regular))
                .foregroundStyle(Color.apolloPrimaryText)
                .keyboardType(.phonePad)
                .multilineTextAlignment(.center)
                .frame(width: 52)

            // Divider
            Rectangle()
                .fill(Color.apolloStroke)
                .frame(width: 1, height: 24)

            // Number field
            TextField("Phone number", text: $phoneNumber)
                .font(.sfPro(17, weight: .regular))
                .foregroundStyle(Color.apolloPrimaryText)
                .keyboardType(.phonePad)
                .focused($fieldFocused)
                .tint(Color.apolloPrimaryText)
        }
        .padding(.vertical, 14)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.apolloStroke),
            alignment: .bottom
        )
    }

    // MARK: - Submit

    private func submitPhone() async {
        guard canSubmit else { return }
        let phone = e164Phone
        do {
            try await authService.signInWithPhone(phone: phone)
            onCodeSent(phone)
        } catch {
            authService.handleError(error)
        }
    }
}

#Preview {
    PhoneEntryView(onCodeSent: { _ in })
        .preferredColorScheme(.dark)
}
