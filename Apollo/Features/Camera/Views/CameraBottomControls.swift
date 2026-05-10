//
//  CameraBottomControls.swift
//  Apollo
//
//  Bottom row of the Camera screen: thumbnail grid (left), shutter (center),
//  camera flip (right). PRD §4D.
//
//  Shutter sizes: outer ring 72pt, inner fill 60pt (normal) / 54pt (pressed).
//  Thumbnail: 56×56pt, rounded corner 8pt, shows today's first photo or
//  a #141414 placeholder.
//

import SwiftUI

struct CameraBottomControls: View {
    let thumbnailURL: URL?
    let isShutterPressed: Bool
    let isFlipping: Bool
    let isAtMaxPhotos: Bool
    let onTapShutter: () -> Void
    let onTapFlip: () -> Void

    var body: some View {
        HStack {
            ThumbnailView(url: thumbnailURL)

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

// MARK: - Subviews

private struct ThumbnailView: View {
    let url: URL?

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholderRect
                    }
                }
            } else {
                placeholderRect
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel("Today's photos")
        .accessibilityHidden(url == nil)
    }

    private var placeholderRect: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.apolloSkeleton) // #141414
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
                    .frame(width: 72, height: 72)

                Circle()
                    .fill(isDisabled ? Color.apolloMuted : Color.apolloText)
                    .frame(
                        width:  isPressed ? 54 : 60,
                        height: isPressed ? 54 : 60
                    )
                    .opacity(isDisabled ? 0.5 : 1.0)
                    .animation(.spring(response: 0.1), value: isPressed)
            }
            .frame(width: 80, height: 80)
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
            thumbnailURL: nil,
            isShutterPressed: false,
            isFlipping: false,
            isAtMaxPhotos: false,
            onTapShutter: {},
            onTapFlip: {}
        )
    }
    .background(Color.apolloBackground)
}
