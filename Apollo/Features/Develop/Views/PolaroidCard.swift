//
//  PolaroidCard.swift
//  Apollo
//
//  343×460 pt polaroid card per Figma nodes 12953:4735 (undeveloped) and
//  12839:4586 (developed). The photo area is 337×337 inset 3pt top/left/right.
//  `progress` drives the reveal: 0 = fully dark/blurred, 1 = sharp and clear.
//

import SwiftUI
import UIKit

struct PolaroidCard: View {
    let image: UIImage
    let win: Win?
    let progress: Double   // 0...1

    // Card dimensions from Figma
    private let cardWidth: CGFloat = 343
    private let cardHeight: CGFloat = 460
    private let photoInset: CGFloat = 3
    private var photoWidth: CGFloat { cardWidth - photoInset * 2 }
    // Photo area height = card height - bottom border (120pt) - top inset (3pt)
    private let photoBorderBottom: CGFloat = 120
    private var photoHeight: CGFloat { cardHeight - photoBorderBottom - photoInset }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Card surface
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(red: 0.03, green: 0.03, blue: 0.03))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 0) {
                // Photo area
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: photoWidth, height: photoHeight)
                        .clipped()
                        .blur(radius: CGFloat(8 * (1 - progress)))

                    // Dramatic dark overlay — fades away as photo develops
                    Color.black
                        .opacity(0.62 * (1 - progress))

                    Color(red: 0.031, green: 0.031, blue: 0.031)
                        .opacity(0.8 * (1 - progress))

                    // Apollo. wordmark — brightens as photo develops
                    Image("ApolloWordmark")
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 22)
                        .opacity(0.6 + 0.4 * progress)
                        .padding(.leading, 10)
                        .padding(.bottom, 8)
                }
                .frame(width: photoWidth, height: photoHeight)
                .clipped()

                // Bottom border — win name + metadata
                VStack(alignment: .leading, spacing: 4) {
                    Text(win?.name ?? "Today")
                        .font(.sfPro(16, weight: .medium))
                        .foregroundStyle(Color(red: 0.71, green: 0.71, blue: 0.71)) // #B5B5B5
                        .lineLimit(1)

                    Text(metadataString)
                        .font(.sfPro(12))
                        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.42)) // #6B6B6B
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(photoInset)
        }
        .frame(width: cardWidth, height: cardHeight)
    }

    private var metadataString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma · M/d/yy"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return "@you · \(formatter.string(from: Date()))"
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        PolaroidCard(
            image: UIImage(systemName: "photo") ?? UIImage(),
            win: Win(id: UUID(), name: "Overnight Oats", currentStreak: 14),
            progress: 0
        )
    }
    .preferredColorScheme(.dark)
}
