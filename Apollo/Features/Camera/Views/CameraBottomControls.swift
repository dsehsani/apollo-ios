//
//  CameraBottomControls.swift
//  Apollo
//
//  Bottom row of the Camera screen: shutter button (center) and camera flip
//  (right). Thumbnail removed — Figma Camera-Active has no bottom-left control.
//

import SwiftUI

struct CameraBottomControls: View {
    let isShutterPressed: Bool
    let isFlipping: Bool
    let isAtMaxPhotos: Bool
    let onTapShutter: () -> Void
    let onTapFlip: () -> Void

    var body: some View {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)

            Spacer()

            ShutterButton(
                isPressed: isShutterPressed,
                isDisabled: isAtMaxPhotos,
                action: onTapShutter
            )

            Spacer()

            FlipButton(isFlipping: isFlipping, action: onTapFlip)
        }
        .padding(.horizontal, 16)
        .frame(height: 96)
    }
}

private struct ShutterButton: View {
    let isPressed: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(Color.apolloStroke, lineWidth: 2)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(isDisabled ? Color.apolloMuted : Color.apolloText)
                    .frame(width: isPressed ? 56 : 66, height: isPressed ? 56 : 66)
                    .opacity(isDisabled ? 0.5 : 1.0)
            }
            .frame(width: 88, height: 88)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel("Take photo")
    }
}

private struct FlipButton: View {
    let isFlipping: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image("IconCameraFlip")
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.apolloText)
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : (isFlipping ? 180 : 0)),
                    axis: (x: 0, y: 1, z: 0)
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: isFlipping)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch camera")
    }
}

#Preview {
    VStack {
        Spacer()
        CameraBottomControls(
            isShutterPressed: false,
            isFlipping: false,
            isAtMaxPhotos: false,
            onTapShutter: {},
            onTapFlip: {}
        )
    }
    .background(Color.apolloBackground)
}
