//
//  OnboardingMatchaCrop.swift
//  Apollo
//
//  The camera-crop UI overlay for OnboardingCaptureView.
//  Figma frame 13031:7230 — group "Group 80":
//    • Hero photo at (0, 122), 402×487, cornerRadius 3
//    • 4×4 white-stroke grid within the crop zone (57,160)→(372,526)
//    • 8 corner anchor marks at the crop rectangle corners
//    • Dimmed rgba(8,8,8,0.46) panels outside the crop zone
//    • "Captured for Matcha Run" semi-transparent pill at (7,463), rotated -6.3°
//

import SwiftUI

struct OnboardingMatchaCrop: View {
    // Figma absolute coords for the crop zone within the 402pt canvas
    private let gridLeft:   CGFloat = 57
    private let gridTop:    CGFloat = 160  // absolute from screen top (photo starts at y=122)
    private let gridRight:  CGFloat = 372
    private let gridBottom: CGFloat = 526

    var body: some View {
        // This view is positioned inside a GeometryReader that starts at y=122
        // (the top edge of the hero photo). Coordinates below are relative to that origin.
        ZStack(alignment: .topLeading) {
            // ── Hero photo ──────────────────────────────────────────────────
            Image("OnboardingMatchaHero")
                .resizable()
                .scaledToFill()
                .frame(width: 402, height: 487)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // ── Dimmed crop margins ──────────────────────────────────────────
            // Left panel: full height of photo, 57pt wide
            Color.black.opacity(0.46)
                .frame(width: 57, height: 487)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            // Right panel: from gridRight to right edge (402-372=30), top 404pt
            Color.black.opacity(0.46)
                .frame(width: 30, height: 404)
                .offset(x: 372)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))

            // Top strip inside crop zone: above the crop (38pt tall, 315pt wide)
            Color.black.opacity(0.46)
                .frame(width: 315, height: 38)
                .offset(x: 57, y: 0)

            // Bottom strip inside crop zone: below crop (83pt tall, 345pt wide)
            Color.black.opacity(0.46)
                .frame(width: 345, height: 83)
                .offset(x: 57, y: 404)

            // ── 4×4 crop grid ────────────────────────────────────────────────
            // Crop zone in photo-local coords: x=57-372 (w=315), y=38-404 (h=366)
            // Divided into 4×4 = 16 cells of 78.75×91.5
            let cellW: CGFloat = 315 / 4
            let cellH: CGFloat = 366 / 4
            ForEach(0..<4, id: \.self) { col in
                ForEach(0..<4, id: \.self) { row in
                    Rectangle()
                        .stroke(Color(red: 0xf3/255, green: 0xf3/255, blue: 0xf3/255), lineWidth: 1)
                        .opacity(0.5)
                        .frame(width: cellW, height: cellH)
                        .offset(x: 57 + CGFloat(col) * cellW,
                                y: 38 + CGFloat(row) * cellH)
                }
            }

            // ── Corner anchor marks ──────────────────────────────────────────
            // 8 anchor shapes at corners of the crop rect in Figma.
            // Positions from metadata: anchors at (57,160)→(372,526) in screen coords
            // = (57,38)→(372,404) in photo-local coords.
            let cropX0: CGFloat = 57
            let cropY0: CGFloat = 38
            let cropX1: CGFloat = 372
            let cropY1: CGFloat = 404

            // Top-left corner
            CornerAnchor(rotation: 0)
                .offset(x: cropX0 + 4, y: cropY0 + 4)

            // Top-right corner
            CornerAnchor(rotation: 90)
                .offset(x: cropX1 - 28, y: cropY0 + 4)

            // Bottom-left corner
            CornerAnchor(rotation: 270)
                .offset(x: cropX0 + 4, y: cropY1 - 28)

            // Bottom-right corner
            CornerAnchor(rotation: 180)
                .offset(x: cropX1 - 28, y: cropY1 - 28)

            // ── "Captured for Matcha Run" pill ───────────────────────────────
            // Figma: frame ~143×144, x=7, y=477 in screen coords = y=355 in photo-local
            CapturedForPill()
                .offset(x: 7, y: 341)
                .rotationEffect(.degrees(-6.3), anchor: .center)
        }
        .frame(width: 402, height: 487)
        .clipped()
    }
}

// An L-shaped corner bracket drawn with two lines
private struct CornerAnchor: View {
    let rotation: Double
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Horizontal bar
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0xf3/255, green: 0xf3/255, blue: 0xf3/255))
                .frame(width: 24, height: 2)
            // Vertical bar
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(red: 0xf3/255, green: 0xf3/255, blue: 0xf3/255))
                .frame(width: 2, height: 24)
        }
        .frame(width: 24, height: 24)
        .rotationEffect(.degrees(rotation))
    }
}

// Semi-transparent pill showing "Captured for Matcha Run" + thumbnail
private struct CapturedForPill: View {
    var body: some View {
        ZStack {
            // Background circle/pill
            Circle()
                .fill(Color(red: 0x08/255, green: 0x08/255, blue: 0x08/255).opacity(0.6))
                .frame(width: 130, height: 130)

            VStack(spacing: 2) {
                Text("Captured for")
                    .font(.sfPro(11, weight: .regular))
                    .foregroundStyle(Color(red: 0xe6/255, green: 0xe6/255, blue: 0xe6/255).opacity(0.8))

                Text("Matcha Run")
                    .font(.sfPro(12, weight: .medium))
                    .foregroundStyle(Color(red: 0xf3/255, green: 0xf3/255, blue: 0xf3/255))

                // Matcha thumbnail at 60% opacity, rotated -1.4°
                Image("OnboardingMatchaThumb")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .opacity(0.6)
                    .rotationEffect(.degrees(-1.4))
            }
        }
        .frame(width: 130, height: 130)
    }
}
