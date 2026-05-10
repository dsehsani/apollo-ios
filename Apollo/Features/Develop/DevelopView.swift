//
//  DevelopView.swift
//  Apollo
//
//  Full-screen Polaroid Develop Flow. Dark background, polaroid card centered,
//  gesture affordance below, checkmark button at bottom once developed.
//
//  Gesture paths:
//    Primary   – shake (ShakeDetector, CMMotionManager)
//    Secondary – rub (DragGesture horizontal > 60% card width)
//    A11y      – tap (when accessibilityReduceMotion is on)
//

import SwiftUI

struct DevelopView: View {
    @State private var viewModel: DevelopViewModel
    let onRetake: () -> Void
    let onConfirm: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = 343
    @State private var rubAccumulation: CGFloat = 0

    init(image: UIImage, win: Win?, onRetake: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        _viewModel = State(initialValue: DevelopViewModel(image: image, win: win))
        self.onRetake = onRetake
        self.onConfirm = onConfirm
    }

    var body: some View {
        ZStack {
            Color(white: 0.031).ignoresSafeArea() // #080808

            // Shake detector — invisible, active only while undeveloped
            ShakeDetector(active: viewModel.phase == .undeveloped) {
                viewModel.triggerDevelop(source: .shake, reduceMotion: reduceMotion)
            }
            .frame(width: 0, height: 0)

            // Centered polaroid + gesture hint
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                PolaroidCard(
                    image: viewModel.image,
                    win: viewModel.win,
                    progress: viewModel.progress
                )
                .padding(.horizontal, 16)
                // Rub gesture
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            guard viewModel.phase == .undeveloped else { return }
                            rubAccumulation += abs(value.translation.width)
                            if rubAccumulation > cardWidth * 0.6 {
                                viewModel.triggerDevelop(source: .rub, reduceMotion: reduceMotion)
                            }
                        }
                        .onEnded { _ in rubAccumulation = 0 }
                )
                // Tap — only when reduce motion is on
                .onTapGesture {
                    if reduceMotion {
                        viewModel.triggerDevelop(source: .tap, reduceMotion: true)
                    }
                }

                GestureHint(visible: viewModel.phase == .undeveloped)

                Spacer(minLength: 0)
            }

            // Chrome overlay
            VStack {
                HStack {
                    Button("retake", action: onRetake)
                        .font(.sfPro(14))
                        .foregroundStyle(Color(white: 0.322)) // #525252
                        .padding(.leading, 16)
                        .padding(.top, 16)
                    Spacer()
                }
                Spacer()
                if viewModel.phase == .developed {
                    CheckmarkButton(onConfirm: onConfirm)
                        .padding(.bottom, 32)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
            }
            .animation(.easeOut(duration: 0.25), value: viewModel.phase)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    DevelopView(
        image: UIImage(systemName: "photo.fill") ?? UIImage(),
        win: Win(id: UUID(), name: "Overnight Oats", currentStreak: 14),
        onRetake: {},
        onConfirm: {}
    )
}
