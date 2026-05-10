//
//  OnboardingCaptureView.swift
//  Apollo
//
//  Second onboarding screen — Figma frame 13031:7230 "iPhone 17 - 3".
//  Apollo wordmark top-left, matcha hero photo with 4×4 crop-grid overlay and
//  dimmed margins, bottom gradient fade, right-aligned Goudy headline
//  "Every win. Documented." and body subtitle, "Continue" primary CTA.
//

import SwiftUI

struct OnboardingCaptureView: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                // ── Apollo wordmark ─────────────────────────────────────────
                // Figma: x=16, y=65, w=116, h=40
                VStack {
                    Spacer().frame(height: 65)
                    OnboardingApolloHeader()
                    Spacer()
                }

                // ── Matcha crop view ────────────────────────────────────────
                // Figma: photo starts at y=122, width=402
                VStack {
                    Spacer().frame(height: 122)
                    OnboardingMatchaCrop()
                        .frame(width: 402, height: 487)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -max(0, min(100, (geo.size.width - 402) / 2)))

                // ── Bottom gradient fade ────────────────────────────────────
                // Figma: top=331, h=293, from rgba(8,8,8,0) → #080808
                VStack {
                    Spacer().frame(height: 331)
                    OnboardingFadeOverlay()
                        .frame(height: 293)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // ── Right-aligned headline "Every win. / Documented." ───────
                // Figma: Goudy Regular 48pt #e6e6e6, right=389, top=488, w=262
                VStack {
                    Spacer().frame(height: 488)
                    Text("Every win.\nDocumented.")
                        .font(.goudyRegular(48))
                        .foregroundStyle(Color.apolloUsername)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 262, alignment: .trailing)
                        .padding(.trailing, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // ── Right-aligned body subtitle ─────────────────────────────
                // Figma: SF Pro Regular 24pt #b5b5b5, right=386, top=634, w=372
                VStack {
                    Spacer().frame(height: 634)
                    Text("Your run. Your meal. Whatever the win was. Take a picture of it.")
                        .font(.sfPro(24, weight: .regular))
                        .foregroundStyle(Color.apolloCaption)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 372, alignment: .trailing)
                        .padding(.trailing, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // ── Primary CTA ─────────────────────────────────────────────
                VStack {
                    Spacer()
                    OnboardingPrimaryButton(title: "Continue", action: onContinue)
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom : 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.apolloBackground)
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingCaptureView(onContinue: {})
        .preferredColorScheme(.dark)
}
