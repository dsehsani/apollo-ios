//
//  CameraCaptureReviewView.swift
//  Apollo
//
//  Full-screen post-shutter review. Appears immediately after capture (<200 ms).
//
//  Layout (Figma 12839:6343, top → bottom):
//    • Top nav (60pt safe-area-aware):
//        Retake (SF Pro Regular 17pt #9c9c9c, left 16pt)
//        Apollo. (Goudy 24pt #e6e6e6, centered)
//        Use Photo (SF Pro Regular 17pt #525252, right 16pt)
//    • 4:5 photo card, full width, cornerRadius 3
//    • 24pt gap
//    • ShootingForLabel (reused)
//    • Spacer
//    • "How did it feel?" pill pinned 16pt above keyboard / safe area
//
//  State behaviours:
//    • Use Photo text: #525252 normally; disabled (#525252) + spinner during .committing
//    • Use Photo: disabled (but not spinner) during .uploading
//    • Retake: #9c9c9c normally; #525252 + disabled during .committing
//    • Swipe down (keyboard closed) → retakePhoto()
//    • Toast appears below top nav (top of content area)
//

import SwiftUI
import UIKit

struct CameraCaptureReviewView: View {
    @Bindable var viewModel: CameraViewModel
    var onClose: () -> Void

    @FocusState private var noteFieldFocused: Bool
    @State private var keyboardHeight: CGFloat = 0

    private let noteLimit = 500

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.apolloBackground.ignoresSafeArea()

            // Scrollable content column
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Nav spacer — the nav bar is overlaid at the top
                    Spacer().frame(height: navHeight)

                    // 4:5 photo card
                    photoCard
                        .padding(.horizontal, 0)

                    Spacer().frame(height: 24)

                    // Shooting for label
                    ShootingForLabel(
                        activeWin: viewModel.activeWin,
                        onTapWinName: viewModel.openWinPicker,
                        onTapAddAWin: viewModel.openWinPicker
                    )
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 32)
                }
            }
            .scrollDisabled(true)

            // Overlay nav bar
            topNav
                .frame(height: navHeight)
                .frame(maxWidth: .infinity)

            // Toast below nav
            if let message = viewModel.transientErrorMessage {
                VStack {
                    Spacer().frame(height: navHeight + 12)
                    ErrorToast(
                        message: message,
                        actionLabel: viewModel.uploadState == .failedOnline ? "Retry" : nil,
                        onAction: viewModel.uploadState == .failedOnline ? {
                            viewModel.clearTransientError()
                            viewModel.retryUpload()
                        } : nil,
                        onDismiss: { viewModel.clearTransientError() }
                    )
                    .padding(.horizontal, 16)
                    Spacer()
                }
                .zIndex(20)
            }

            // "How did it feel?" pill — pinned above keyboard / safe area
            VStack {
                Spacer()
                noteInputPill
                    .padding(.horizontal, 16)
                    .padding(.bottom, max(keyboardHeight, 0) + 16)
            }
            .animation(.spring(response: 0.3), value: keyboardHeight)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .tabBar)
        .simultaneousGesture(swipeDownGesture)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = frame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    // MARK: - Top nav

    private var topNav: some View {
        ZStack {
            // Centred wordmark
            Text("Apollo.")
                .font(.goudyItalic(24))
                .foregroundStyle(Color(white: 0xe6 / 255.0))
                .frame(maxWidth: .infinity)

            HStack {
                // Retake
                Button {
                    noteFieldFocused = false
                    viewModel.retakePhoto()
                } label: {
                    Text("Retake")
                        .font(.sfPro(17))
                        .foregroundStyle(retakeColor)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.uploadState == .committing)
                .padding(.leading, 16)

                Spacer()

                // Use Photo / spinner
                Button {
                    noteFieldFocused = false
                    viewModel.usePhoto()
                } label: {
                    if viewModel.uploadState == .committing {
                        ProgressView()
                            .tint(Color.apolloText)
                            .frame(width: 60)
                    } else {
                        Text("Use Photo")
                            .font(.sfPro(17))
                            .foregroundStyle(usePhotoColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isUsePhotoDisabled)
                .padding(.trailing, 16)
            }
        }
        .frame(height: navHeight)
        .background(Color.apolloBackground.opacity(0.95).ignoresSafeArea(edges: .top))
    }

    // MARK: - Photo card

    @ViewBuilder
    private var photoCard: some View {
        if let image = viewModel.lastCapturedImage {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(4.0 / 5.0, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color.apolloSkeleton)
                .aspectRatio(4 / 5, contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Note pill

    private var noteInputPill: some View {
        ZStack(alignment: .leading) {
            if viewModel.privateNote.isEmpty {
                Text("How did it feel?")
                    .font(.sfPro(16))
                    .foregroundStyle(Color(white: 0x83 / 255.0))
                    .padding(.leading, 24)
                    .allowsHitTesting(false)
            }
            TextField("", text: $viewModel.privateNote)
                .font(.sfPro(16))
                .foregroundStyle(Color(white: 0xe6 / 255.0))
                .tint(Color.apolloText)
                .focused($noteFieldFocused)
                .padding(.leading, 24)
                .padding(.trailing, 16)
                .onChange(of: viewModel.privateNote) { _, newValue in
                    if newValue.count > noteLimit {
                        viewModel.privateNote = String(newValue.prefix(noteLimit))
                    }
                }
        }
        .frame(height: 43)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color(white: 0x21 / 255.0))
                .overlay(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .stroke(Color(white: 0x6b / 255.0), lineWidth: 1)
                )
        )
    }

    // MARK: - Gestures

    private var swipeDownGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                guard !noteFieldFocused,
                      value.translation.height > 60,
                      abs(value.translation.height) > abs(value.translation.width) else { return }
                viewModel.retakePhoto()
            }
    }

    // MARK: - Helpers

    /// Height of the nav row, accounting for the safe area.
    private var navHeight: CGFloat { 60 }

    private var isUsePhotoDisabled: Bool {
        viewModel.uploadState == .committing || viewModel.uploadState == .uploading
    }

    private var usePhotoColor: Color {
        Color(white: 0x52 / 255.0)
    }

    private var retakeColor: Color {
        viewModel.uploadState == .committing
            ? Color(white: 0x52 / 255.0)
            : Color(white: 0x9c / 255.0)
    }
}

#Preview {
    let vm = CameraViewModel(
        repository: MockCameraRepository(forceState: .withWins),
        postRepository: MockPostRepository()
    )
    return CameraCaptureReviewView(viewModel: vm, onClose: {})
        .preferredColorScheme(.dark)
}
