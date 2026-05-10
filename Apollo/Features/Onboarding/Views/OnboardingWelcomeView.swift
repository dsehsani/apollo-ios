//
//  OnboardingWelcomeView.swift
//  Apollo
//
//  First onboarding screen — Figma frame 13036:7412 "iPhone 17 - 4".
//  Background gradient #212121 → #080808, three rotated phone mockup images,
//  bottom gradient fade, "Welcome to" Goudy 48pt + Apollo large wordmark vector,
//  and a "Get Started" primary button at the bottom.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                // Background gradient: #212121 at top → #080808 at bottom
                LinearGradient(
                    colors: [
                        Color(red: 0x21/255, green: 0x21/255, blue: 0x21/255),
                        Color.apolloBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Decorative phone mockup images ──────────────────────────────
                // Positions mirror Figma absolute coords scaled to a 402pt-wide canvas.
                // Group 84 (2) 2 — tall left phone, rotated -8.26°
                Image("OnboardingWelcomePhone3")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 127)
                    .rotationEffect(.degrees(-8.26))
                    .position(x: 25 + 63, y: 66 + 252) // center = origin + halfH

                // Group 74 1 — small top-right phone, rotated +6.64°
                Image("OnboardingWelcomePhone1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 154)
                    .rotationEffect(.degrees(6.64))
                    .position(x: 217 + 77, y: 68 + 66)

                // Group 83 1 — medium mid-right phone, rotated +6.97°
                Image("OnboardingWelcomePhone2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170)
                    .rotationEffect(.degrees(6.97))
                    .position(x: 187 + 85, y: 135 + 110)

                // ── Bottom gradient fade ────────────────────────────────────────
                // Figma: from y=245, h=398 — covers lower portion over the photos
                VStack {
                    Spacer().frame(height: 245)
                    OnboardingFadeOverlay()
                        .frame(height: 398)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // ── Text content ────────────────────────────────────────────────
                // "Welcome to" — Goudy Regular 48pt, x=90, y=444, w=222, color #e6e6e6
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 444)
                    Text("Welcome to")
                        .font(.goudyRegular(48))
                        .foregroundStyle(Color.apolloUsername)
                        .frame(width: 222, alignment: .leading)
                        .padding(.leading, 90)

                    // Apollo wordmark — Group 45 1: w=343, h=118, x=29, y=518
                    // y=518 means offset from top by 518; the text ends around 444+65=509 so gap ~9pt
                    Image("ApolloWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 343)
                        .padding(.leading, 29)
                        .padding(.top, 9)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                // ── Primary CTA ─────────────────────────────────────────────────
                // Figma: y=753, h=44, x=16, w=370
                VStack {
                    Spacer()
                    OnboardingPrimaryButton(title: "Get Started", action: onContinue)
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
    OnboardingWelcomeView(onContinue: {})
        .preferredColorScheme(.dark)
}
