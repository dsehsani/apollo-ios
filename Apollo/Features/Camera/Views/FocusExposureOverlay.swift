//
//  FocusExposureOverlay.swift
//  Apollo
//
//  Native-camera-style focus square + vertical sun-drag exposure control.
//  Appears at the tap point; fades automatically after 3 s of no interaction.
//

import SwiftUI

struct FocusExposureOverlay: View {
    /// Nil means hidden. Non-nil is the position in the viewfinder's coordinate space.
    let point: CGPoint?
    let exposureBias: Float
    let onExposureChange: (Float) -> Void
    let onInteraction: () -> Void

    private let squareSize: CGFloat = 70
    private let sunOffset: CGFloat = 16   // gap between square edge and sun icon
    private let dragRange: CGFloat = 100  // ±pt maps to ±2 EV
    private let evRange: Float = 2.0

    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging: Bool = false

    var body: some View {
        if let point {
            ZStack(alignment: .topLeading) {
                // Focus square
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.yellow.opacity(0.85), lineWidth: 1.5)
                    .frame(width: squareSize, height: squareSize)

                // Sun icon + drag handle
                VStack(spacing: 0) {
                    Image("IconSun")
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 22, height: 22)
                        .foregroundStyle(Color.yellow.opacity(0.85))
                        .offset(y: sunDragOffset)
                }
                .frame(width: 44, height: squareSize + 80, alignment: .center)
                .offset(x: squareSize + sunOffset - 11, y: -40 + squareSize / 2)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            isDragging = true
                            let delta = Float(-value.translation.height / dragRange) * evRange
                            let base = Float(exposureBias)
                            let target = max(-evRange, min(evRange, base + delta - Float(dragTranslation / dragRange) * evRange))
                            dragTranslation = value.translation.height
                            onExposureChange(target)
                            onInteraction()
                        }
                        .onEnded { _ in
                            isDragging = false
                            dragTranslation = 0
                            onInteraction()
                        }
                )
            }
            // Centre the square on the tap point
            .position(x: point.x, y: point.y)
            .transition(.opacity)
            .animation(.easeOut(duration: 0.15), value: point)
        }
    }

    // Sun slides up when bias > 0, down when bias < 0, ±40 pt max
    private var sunDragOffset: CGFloat {
        CGFloat(-exposureBias) / CGFloat(evRange) * 40
    }
}
