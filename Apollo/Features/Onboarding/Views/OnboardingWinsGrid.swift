//
//  OnboardingWinsGrid.swift
//  Apollo
//
//  The two-column photo grid + three rotated emoji reaction circles
//  used in OnboardingWinsView.
//
//  Figma frame 13025:5267 "Frame 160" at x=0, y=165.77 inside Group 78.
//  Left column: 258×303. Right column 141pt wide with 6 rows separated by 3pt gaps.
//  Emoji reaction circles float on top at absolute positions.
//

import SwiftUI

struct OnboardingWinsGrid: View {
    private let gap: CGFloat = 3
    private let leftW: CGFloat = 258
    private let rightW: CGFloat = 141
    private let totalH: CGFloat = 303

    var body: some View {
        ZStack(alignment: .topLeading) {
            // ── Two-column photo grid ──────────────────────────────────────
            HStack(alignment: .top, spacing: gap) {
                // Left: one tall image
                Image("OnboardingWinsLeft")
                    .resizable()
                    .scaledToFill()
                    .frame(width: leftW, height: totalH)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                // Right: 6 rows (clipped to totalH)
                VStack(alignment: .leading, spacing: gap) {
                    // Row 1: 141×141
                    Image("OnboardingWinsRight1")
                        .resizable()
                        .scaledToFill()
                        .frame(width: rightW, height: 141)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Row 2: 141×71
                    Image("OnboardingWinsRight2")
                        .resizable()
                        .scaledToFill()
                        .frame(width: rightW, height: 71)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                    // Row 3: two 69×85 side by side
                    HStack(spacing: gap) {
                        Image("OnboardingWinsRight3a")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 69, height: 85)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        Image("OnboardingWinsRight3b")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 69, height: 85)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .frame(width: rightW, height: totalH)
                .clipped()
            }
            .frame(width: leftW + gap + rightW, height: totalH)

            // ── Emoji reaction circles ─────────────────────────────────────
            // Positions are relative to the top-left of this view.
            // In Figma the emoji frames are within Group 78 at y=122, and
            // the grid is at y=165.77, so emoji y offsets are (figma_y - 165.77).

            // 💪 — 66×66 black circle, Figma (194, 236) → local (194, 70)
            EmojiReactionCircle(emoji: "💪", size: 66, emojiSize: 36, rotation: 7.36)
                .offset(x: 194, y: 236 - 165)

            // 👑 — 87×89 black circle, Figma (261, 278) → local (261, 112)
            EmojiReactionCircle(emoji: "👑", size: 87, emojiSize: 48, rotation: -12.22)
                .offset(x: 261, y: 278 - 165)

            // ❤️ — 88×92 outer frame, 75×80 inner circle, Figma (305, 371) → local (305, 205)
            EmojiReactionCircle(emoji: "❤️", size: 80, emojiSize: 40, rotation: -12.22)
                .rotationEffect(.degrees(10.17))
                .offset(x: 305, y: 371 - 165)
        }
    }
}

private struct EmojiReactionCircle: View {
    let emoji: String
    let size: CGFloat
    let emojiSize: CGFloat
    let rotation: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.apolloBackground)
                .frame(width: size, height: size)
            Text(emoji)
                .font(.system(size: emojiSize))
                .rotationEffect(.degrees(rotation))
        }
        .frame(width: size, height: size)
    }
}
