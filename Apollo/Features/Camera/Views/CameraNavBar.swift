//
//  CameraNavBar.swift
//  Apollo
//
//  Camera screen top navigation: chevron-down dismiss on the left, Apollo
//  wordmark centered, flash toggle on the right. PRD §4A.
//

import SwiftUI

struct CameraNavBar: View {
    let flash: CameraFlashMode
    let onClose: () -> Void
    let onToggleFlash: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            CameraIconButton(
                asset: "IconChevronDown",
                tint: .apolloText,
                accessibilityLabel: "Close camera",
                action: onClose
            )

            Spacer(minLength: 0)

            Text("Apollo.")
                .font(.goudyItalic(24))
                .foregroundStyle(Color.apolloText)
                .accessibilityLabel("Apollo")

            Spacer(minLength: 0)

            CameraIconButton(
                asset: "IconBolt",
                tint: flashTint,
                accessibilityLabel: "\(flash.voiceOverLabel). Double tap to change.",
                action: onToggleFlash
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(height: 60)
    }

    private var flashTint: Color {
        switch flash {
        case .off: return .apolloIconStroke
        case .on: return .apolloText
        case .auto: return Color(red: 0xe8 / 255, green: 0xa8 / 255, blue: 0x00 / 255)
        }
    }
}

struct CameraIconButton: View {
    let asset: String
    let tint: Color
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(asset)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack {
        CameraNavBar(flash: .off, onClose: {}, onToggleFlash: {})
        CameraNavBar(flash: .on, onClose: {}, onToggleFlash: {})
        CameraNavBar(flash: .auto, onClose: {}, onToggleFlash: {})
    }
    .background(Color.apolloBackground)
}
