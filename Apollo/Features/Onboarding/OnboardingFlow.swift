//
//  OnboardingFlow.swift
//  Apollo
//
//  NavigationStack host for the full onboarding flow:
//    Welcome → Every win. Documented. → Your Wins. Every Day.
//           → Sign In → (Phone Entry → OTP Verification)
//
//  Successful auth (Apple, Google, or verified phone OTP) is detected by
//  SessionStore's authStateChanges listener in ApolloApp, which flips the
//  app's root from this flow to RootTabView. We still call onFinish() on
//  each terminal screen so any caller that wants to react locally can.
//

import SwiftUI

struct OnboardingFlow: View {
    let onFinish: () -> Void

    private enum Step: Hashable {
        case capture
        case wins
        case signIn
        case phoneEntry
        case phoneVerify(phone: String)
    }

    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcomeView {
                path.append(Step.capture)
            }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .capture:
                    OnboardingCaptureView {
                        path.append(Step.wins)
                    }
                    .toolbar(.hidden, for: .navigationBar)

                case .wins:
                    OnboardingWinsView {
                        path.append(Step.signIn)
                    }
                    .toolbar(.hidden, for: .navigationBar)

                case .signIn:
                    SignInView(
                        onSignedIn: onFinish,
                        onUsePhone: { path.append(Step.phoneEntry) }
                    )
                    .toolbar(.hidden, for: .navigationBar)

                case .phoneEntry:
                    PhoneEntryView(onCodeSent: { phone in
                        path.append(Step.phoneVerify(phone: phone))
                    })
                    .toolbar(.hidden, for: .navigationBar)

                case .phoneVerify(let phone):
                    OtpVerificationView(phone: phone, onVerified: onFinish)
                        .toolbar(.hidden, for: .navigationBar)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

#Preview {
    OnboardingFlow(onFinish: {})
        .preferredColorScheme(.dark)
}
