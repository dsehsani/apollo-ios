//
//  OnboardingWinsView.swift
//  Apollo
//
//  Third onboarding screen — Figma frame 13025:5208 "iPhone 17 - 2".
//  Apollo wordmark + post-header row, two-column photo grid with floating
//  emoji reaction circles, bottom gradient fade, left-aligned Goudy headline
//  "Your Wins. Every Day." and body subtitle, "Continue" primary CTA.
//

import SwiftUI

struct OnboardingWinsView: View {
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

                // ── Post-header row ─────────────────────────────────────────
                // Figma: Frame 46, x=16, y=122, w=370, h=36
                VStack {
                    Spacer().frame(height: 122)
                    PostHeaderRow()
                        .padding(.horizontal, 16)
                        .frame(height: 36)
                    Spacer()
                }

                // ── Photo grid with emoji circles ────────────────────────────
                // Figma: Frame 160 at y=(122+165.77)=287.77
                VStack {
                    Spacer().frame(height: 287)
                    OnboardingWinsGrid()
                        .frame(width: 402, height: 303)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(x: -max(0, min(100, (geo.size.width - 402) / 2)))

                // ── Bottom gradient fade ────────────────────────────────────
                // Figma: y=387, h=101, from transparent → #080808
                VStack {
                    Spacer().frame(height: 387)
                    OnboardingFadeOverlay()
                        .frame(height: 101)
                    Spacer()
                }
                .frame(maxWidth: .infinity)

                // ── "Your Wins. Every Day." Goudy headline ──────────────────
                // Figma: Goudy Regular 48pt #e6e6e6, x=16, y=488, w=222 (2 lines)
                VStack {
                    Spacer().frame(height: 488)
                    Text("Your Wins.\nEvery Day. ")
                        .font(.goudyRegular(48))
                        .foregroundStyle(Color.apolloUsername)
                        .multilineTextAlignment(.leading)
                        .frame(width: 222, alignment: .leading)
                        .padding(.leading, 16)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                // ── Body subtitle ───────────────────────────────────────────
                // Figma: SF Pro Regular 24pt #b5b5b5, x=16, y=634, w=370
                VStack {
                    Spacer().frame(height: 634)
                    Text("Post what you did. Watch your people do the same. Show up.")
                        .font(.sfPro(24, weight: .regular))
                        .foregroundStyle(Color.apolloCaption)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                    Spacer()
                }

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

// Post header: avatar, username + streak, wins count
private struct PostHeaderRow: View {
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Avatar circle 33×33
            Image("OnboardingWinsAvatar")
                .resizable()
                .scaledToFill()
                .frame(width: 33, height: 33)
                .clipShape(Circle())

            // Username + streak
            VStack(alignment: .leading, spacing: 0) {
                Text("win.every_day")
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloUsername)
                    .kerning(-0.28)

                Text("6:30 AM・88d Streak")
                    .font(.sfPro(12, weight: .regular))
                    .foregroundStyle(Color.apolloTimeStreak)
                    .kerning(-0.24)
            }
            .padding(.leading, 10)

            Spacer()

            // Wins count — right-aligned "12" over "Wins"
            VStack(alignment: .trailing, spacing: 0) {
                Text("12")
                    .font(.sfPro(20, weight: .semibold))
                    .foregroundStyle(Color.apolloWinsValue)

                Text("Wins")
                    .font(.sfPro(10, weight: .regular))
                    .foregroundStyle(Color.apolloWinsLabel)
            }
        }
    }
}

#Preview {
    OnboardingWinsView(onContinue: {})
        .preferredColorScheme(.dark)
}
