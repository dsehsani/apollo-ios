//
//  FullScreenPhotoViewer.swift
//  Apollo
//
//  Polaroid-style full-screen photo viewer per Figma 12839:4259.
//  Photos are presented as a polaroid deck. Swiping left/right flicks through
//  them with per-card rotation, scale, and opacity transforms that mimic
//  sliding through a stack of physical polaroids. Vertical drag dismisses.
//

import SwiftUI
import Kingfisher
import UIKit

// MARK: - Main viewer

struct FullScreenPhotoViewer: View {
    var post: Post
    var startingIndex: Int
    var onClose: () -> Void

    @State private var currentIndex: Int
    @State private var dismissOffset: CGFloat = 0
    @State private var isDismissing: Bool = false

    private var urls: [URL?] {
        var result: [URL?] = [post.mainPhotoURL]
        result += post.towerPhotos.sorted { $0.index < $1.index }.map(\.url)
        return result
    }

    init(post: Post, startingIndex: Int, onClose: @escaping () -> Void) {
        self.post = post
        self.startingIndex = startingIndex
        self.onClose = onClose
        _currentIndex = State(initialValue: max(0, min(startingIndex, max(0, post.photoCount - 1))))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            // Top gradient fade to background (107pt, matches Figma 12839:4352)
            LinearGradient(
                colors: [Color(white: 24/255), Color.apolloBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 107)
            .frame(maxWidth: .infinity)
            .allowsHitTesting(false)
            .zIndex(1)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                    .zIndex(2)

                PolaroidDeck(
                    post: post,
                    urls: urls,
                    currentIndex: $currentIndex,
                    onDismiss: {
                        withAnimation(.easeOut(duration: 0.25)) {
                            isDismissing = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onClose() }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(y: dismissOffset)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Analytics.track(.photoViewerOpened, [
                "post_id": post.id.uuidString,
                "starting_index": startingIndex,
                "photo_count": urls.count
            ])
        }
    }

    // MARK: - Top bar (Figma 12839:4354)
    // top=59, left=16, width=370, height=31 within 402pt frame → padded 16 each side

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.apolloSkeleton)  // #141414
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text(post.user.username)
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloPrimaryText)

            Spacer()

            Button {
                // TODO: wire to share sheet
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.apolloPrimaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.apolloSkeleton)  // #141414
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Polaroid deck carousel

private struct PolaroidDeck: View {
    var post: Post
    var urls: [URL?]
    @Binding var currentIndex: Int
    var onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Card from Figma: width=368, height=486 (3+359+3 + 120 label)
    private let cardWidth:  CGFloat = 368
    private let cardHeight: CGFloat = 486

    // Drag state
    @State private var dragX: CGFloat = 0
    @State private var dragY: CGFloat = 0
    @State private var dragAxis: DragAxis = .undecided
    @State private var verticalDismissOffset: CGFloat = 0

    private enum DragAxis { case undecided, horizontal, vertical }

    var body: some View {
        ZStack {
            // Render currentIndex ± 2 for performance
            let range = max(0, currentIndex - 2)...min(urls.count - 1, currentIndex + 2)
            ForEach(Array(range), id: \.self) { i in
                let (xOff, yOff, scale, rotation, opacity, zIdx) = transforms(for: i)

                PolaroidCardView(post: post, url: urls[i])
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .offset(x: xOff, y: yOff + verticalDismissOffset)
                    .opacity(opacity)
                    .zIndex(zIdx)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 8, coordinateSpace: .local)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = value.translation.height

                    if dragAxis == .undecided {
                        if abs(dx) > abs(dy) + 4 {
                            dragAxis = .horizontal
                            // #region agent log
                            debugLog("axis locked horizontal", data: ["dx": Double(dx), "dy": Double(dy)], hyp: "H-A")
                            // #endregion
                        } else if abs(dy) > abs(dx) + 4 {
                            dragAxis = .vertical
                        }
                    }

                    switch dragAxis {
                    case .horizontal:
                        // Clamp at edges so card doesn't fly past boundary
                        let clampedMin: CGFloat = currentIndex == 0 ? -40 : -cardWidth
                        let clampedMax: CGFloat = currentIndex == urls.count - 1 ? 40 : cardWidth
                        dragX = min(clampedMax, max(clampedMin, dx))
                    case .vertical:
                        if dy > 0 {
                            verticalDismissOffset = dy
                        }
                    case .undecided:
                        break
                    }
                }
                .onEnded { value in
                    let dx = value.translation.width
                    let predictedDx = value.predictedEndTranslation.width
                    let dy = value.translation.height
                    let predictedDy = value.predictedEndTranslation.height

                    // #region agent log
                    let focusedDelta = CGFloat(currentIndex - currentIndex) - (dragAxis == .horizontal ? dragX / cardWidth : 0)
                    let focusedXOff  = focusedDelta * cardWidth * 0.78
                    debugLog("onEnded", data: [
                        "dx": Double(dx), "dragX": Double(dragX),
                        "focusedDelta": Double(focusedDelta), "focusedXOff": Double(focusedXOff),
                        "currentIndex": currentIndex, "urlsCount": urls.count
                    ], hyp: "H-A,H-B,H-C")
                    // #endregion

                    switch dragAxis {
                    case .horizontal:
                        let threshold = cardWidth * 0.22
                        let velThreshold = cardWidth * 0.5
                        let goNext = dx < -threshold || predictedDx < -velThreshold
                        let goPrev = dx > threshold || predictedDx > velThreshold
                        if goNext && currentIndex < urls.count - 1 {
                            fireHaptic()
                            withAnimation(snapSpring) { currentIndex += 1; dragX = 0 }
                        } else if goPrev && currentIndex > 0 {
                            fireHaptic()
                            withAnimation(snapSpring) { currentIndex -= 1; dragX = 0 }
                        } else {
                            withAnimation(snapSpring) { dragX = 0 }
                        }
                    case .vertical:
                        if abs(dy) > 120 || abs(predictedDy) > 200 {
                            onDismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                verticalDismissOffset = 0
                            }
                        }
                    case .undecided:
                        withAnimation(snapSpring) { dragX = 0 }
                    }
                    // #region agent log
                    debugLog("post-switch state reset", data: ["dragX_before_reset": Double(dragX), "dragAxis_was_horizontal": dragAxis == .horizontal], hyp: "H-B,H-C")
                    // #endregion
                    dragAxis = .undecided
                    dragX = 0
                }
        )
    }

    // MARK: - Debug logging (agent instrumentation – remove after verification)

    // #region agent log
    private func debugLog(_ msg: String, data: [String: Any], hyp: String, runId: String = "run1") {
        let logPath = "/Volumes/Darius_SSD/Apollo/Apollo/.cursor/debug-ca78b6.log"
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = ["sessionId": "ca78b6", "timestamp": ts, "runId": runId,
                                      "hypothesisId": hyp, "message": msg, "data": data]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              var line = String(data: jsonData, encoding: .utf8) else { return }
        line += "\n"
        guard let lineBytes = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logPath) {
            if let fh = FileHandle(forWritingAtPath: logPath) { fh.seekToEndOfFile(); fh.write(lineBytes); fh.closeFile() }
        } else { try? line.write(toFile: logPath, atomically: false, encoding: .utf8) }
    }
    // #endregion

    // MARK: - Per-card transform math

    /// Returns (xOffset, yOffset, scale, rotation, opacity, zIndex)
    private func transforms(for i: Int) -> (CGFloat, CGFloat, CGFloat, Angle, Double, Double) {
        // delta: 0 = focused card, ±1 = immediate neighbour, etc.
        let delta = CGFloat(i - currentIndex) - (dragAxis == .horizontal ? dragX / cardWidth : 0)
        let absD  = min(abs(delta), 2.0)

        let xOffset  = delta * cardWidth * 0.78
        let yOffset: CGFloat = reduceMotion ? 0 : 14 * absD
        let scale    = reduceMotion ? max(0.88, 1 - 0.04 * absD) : max(0.76, 1 - 0.12 * absD)
        let rotation = reduceMotion ? Angle.zero : Angle(degrees: Double(delta) * 6)
        let opacity  = max(0, 1 - 0.5 * absD)
        let zIndex   = Double(10 - absD * 5)   // focused = 10, next = 7.5, further = 5

        return (xOffset, yOffset, scale, rotation, opacity, zIndex)
    }

    private var snapSpring: Animation {
        reduceMotion
            ? .easeOut(duration: 0.25)
            : .interpolatingSpring(stiffness: 220, damping: 26)
    }

    private func fireHaptic() {
        let gen = UIImpactFeedbackGenerator(style: .soft)
        gen.prepare()
        gen.impactOccurred()
    }
}

// MARK: - Polaroid card (Figma 12839:4337)
// Card: 368×486, bg #080808, cornerRadius=3, shadow 0 4 8 rgba(0,0,0,.15)
// Photo inset: 3pt top + 3pt sides = 359×359 photo, 120pt label area at bottom

private struct PolaroidCardView: View {
    var post: Post
    var url: URL?

    private let cardWidth:   CGFloat = 368
    private let photoSize:   CGFloat = 359   // 368 - 3*2
    private let labelHeight: CGFloat = 120
    private let inset:       CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            photoCell
                .padding(.top, inset)
                .padding(.horizontal, inset)

            labelArea
                .frame(height: labelHeight, alignment: .topLeading)
        }
        .frame(width: cardWidth)
        .background(Color.apolloBackground)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 4)
    }

    // MARK: Photo — scaledToFill, clipped to exact 359×359

    @ViewBuilder
    private var photoCell: some View {
        Group {
            if let url {
                KFImage(url)
                    .resizable()
                    .placeholder {
                        Color.apolloSkeleton
                            .frame(width: photoSize, height: photoSize)
                    }
                    .scaledToFill()
            } else {
                ZStack {
                    Color.apolloSkeleton
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.apolloIconStroke)
                        Text("Photo unavailable")
                            .font(.sfPro(12))
                            .foregroundStyle(Color.apolloCaption)
                    }
                }
            }
        }
        .frame(width: photoSize, height: photoSize)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    // MARK: Label area
    // Figma: wordmark 121×41 at left=17.06 from card, win text 14pt medium #B5B5B5,
    //        meta 10pt regular #6B6B6B. Horizontal padding = 14pt from card edge
    //        (inset 3 + 11 inner = 14 from card edge, matching the ~17 offset Figma shows).

    private var labelArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image("ApolloWordmark")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(height: 41)
                .padding(.bottom, 3)

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloCaption)       // #B5B5B5
                    .lineLimit(1)
            }

            Text(metaLine)
                .font(.sfPro(10))
                .foregroundStyle(Color.apolloWinsLabel)         // #6B6B6B
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metaLine: String {
        let tf = DateFormatter()
        tf.dateFormat = "h:mma"
        tf.amSymbol = "am"
        tf.pmSymbol = "pm"
        let df = DateFormatter()
        df.dateFormat = "M/d/yy"
        return "@\(post.user.username) · \(tf.string(from: post.createdAt)) · \(df.string(from: post.createdAt))"
    }
}
