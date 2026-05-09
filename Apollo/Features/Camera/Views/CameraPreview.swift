//
//  CameraPreview.swift
//  Apollo
//
//  SwiftUI wrapper around `AVCaptureVideoPreviewLayer`. Hosts the live
//  viewfinder, owns tap-to-focus and pinch-to-zoom gestures, and surfaces
//  user interactions back to the view model.
//
//  The tap callback now returns both the AVFoundation device point (0-1
//  normalised, used for focus/exposure) and the UIView-local point (used to
//  position the SwiftUI FocusExposureOverlay).
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var isMirrored: Bool
    /// (devicePoint, layerPoint) — devicePoint for AVFoundation focus/exposure,
    /// layerPoint for SwiftUI overlay placement.
    var onTapToFocus: (CGPoint, CGPoint) -> Void
    var onZoomChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        if let connection = view.previewLayer.connection {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isMirrored
            }
        }

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        context.coordinator.previewView = view
        return view
    }

    func updateUIView(_ view: PreviewUIView, context: Context) {
        context.coordinator.onTapToFocus = onTapToFocus
        context.coordinator.onZoomChange = onZoomChange

        if let connection = view.previewLayer.connection,
           connection.isVideoMirroringSupported,
           connection.isVideoMirrored != isMirrored {
            connection.isVideoMirrored = isMirrored
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onTapToFocus: onTapToFocus, onZoomChange: onZoomChange)
    }

    final class Coordinator: NSObject {
        var onTapToFocus: (CGPoint, CGPoint) -> Void
        var onZoomChange: (CGFloat) -> Void
        weak var previewView: PreviewUIView?
        private var pinchStartScale: CGFloat = 1.0

        init(onTapToFocus: @escaping (CGPoint, CGPoint) -> Void, onZoomChange: @escaping (CGFloat) -> Void) {
            self.onTapToFocus = onTapToFocus
            self.onZoomChange = onZoomChange
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = previewView else { return }
            let layerPoint = recognizer.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: layerPoint)
            onTapToFocus(devicePoint, layerPoint)
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                pinchStartScale = 1.0
            case .changed:
                let factor = recognizer.scale
                onZoomChange(factor)
                pinchStartScale = factor
            default:
                break
            }
        }
    }

    final class PreviewUIView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
