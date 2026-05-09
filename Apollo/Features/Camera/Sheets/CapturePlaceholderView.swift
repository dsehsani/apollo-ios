//
//  CapturePlaceholderView.swift
//  Apollo
//
//  Post-shutter Capture screen. Shows the just-taken photo full-screen with
//  black letterbox bars matching the Camera viewfinder. Header: Retake (left) /
//  Apollo. (center) / Use Photo (right) per Figma frame 12839:6175+.
//
//  Retake  → onRetake (dismiss, return to live camera)
//  Use Photo → onUsePhoto (proceed to Polaroid Develop Flow)
//

import SwiftUI
import UIKit

struct CapturePlaceholderView: View {
    let image: UIImage?
    let win: Win?
    let onRetake: () -> Void
    let onUsePhoto: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            // Photo in a 4:5 letterbox matching the viewfinder
            GeometryReader { proxy in
                let photoHeight = proxy.size.width * 5.0 / 4.0
                VStack(spacing: 0) {
                    Color.black.frame(maxHeight: .infinity)
                    photoContent
                        .frame(width: proxy.size.width, height: photoHeight)
                        .clipped()
                    Color.black.frame(maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()

            // Header
            HStack(spacing: 0) {
                Button("Retake", action: onRetake)
                    .font(.sfPro(15, weight: .regular))
                    .foregroundStyle(Color.apolloText)
                    .frame(width: 80, alignment: .leading)
                    .padding(.leading, 16)
                    .accessibilityLabel("Retake photo")

                Spacer(minLength: 0)

                Image("ApolloWordmark")
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 28)
                    .accessibilityLabel("Apollo")

                Spacer(minLength: 0)

                Button("Use Photo", action: onUsePhoto)
                    .font(.sfPro(15, weight: .regular))
                    .foregroundStyle(Color.apolloText)
                    .frame(width: 80, alignment: .trailing)
                    .padding(.trailing, 16)
                    .accessibilityLabel("Use this photo")
            }
            .frame(height: 60)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var photoContent: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityLabel("Captured photo")
        } else {
            Color.apolloBackground
        }
    }
}

#Preview {
    CapturePlaceholderView(
        image: nil,
        win: Win(id: UUID(), name: "Overnight Oats", currentStreak: 14),
        onRetake: {},
        onUsePhoto: {}
    )
}
