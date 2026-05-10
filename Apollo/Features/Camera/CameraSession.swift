//
//  CameraSession.swift
//  Apollo
//
//  Thin wrapper over AVCaptureSession. Owns the session, the active device
//  input, and the photo output. Exposes a small async API the view model and
//  preview layer can call (configure, start, stop, flip, zoom, focus, capture).
//
//  All AVCaptureSession mutations are serialized on a private queue. The
//  session reference itself is exposed publicly so the preview layer can bind
//  to it; AVCaptureSession is documented as thread-safe for that read.
//

@preconcurrency import AVFoundation
import CoreGraphics
import Foundation
import UIKit

nonisolated final class CameraSession: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {

    enum SessionError: Error, Sendable {
        case noDevice
        case configurationFailed
        case captureFailed
        case notRunning
    }

    /// Public for `AVCaptureVideoPreviewLayer.session`. Reading is safe from any thread.
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.apollo.camera.session", qos: .userInitiated)
    private let photoOutput = AVCapturePhotoOutput()
    private var currentInput: AVCaptureDeviceInput?
    private var currentDevice: AVCaptureDevice?
    private var currentPosition: CameraPosition = .back

    private var captureContinuation: CheckedContinuation<Data, Error>?

    // MARK: - Lifecycle

    func configure(position: CameraPosition) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    try self.configureSync(position: position)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async { [self] in
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume()
            }
        }
    }

    func stop() {
        // PRD §13: session must be stopped synchronously on dismiss to release memory.
        sessionQueue.sync {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    // MARK: - Position / flip

    func setPosition(_ position: CameraPosition) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [self] in
                do {
                    self.session.beginConfiguration()
                    if let currentInput {
                        self.session.removeInput(currentInput)
                    }
                    try self.attachInput(for: position)
                    self.currentPosition = position
                    self.session.commitConfiguration()
                    continuation.resume()
                } catch {
                    self.session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    var position: CameraPosition { currentPosition }

    // MARK: - Zoom / focus

    func setZoom(_ factor: CGFloat) {
        sessionQueue.async { [self] in
            guard let device = currentDevice else { return }
            let clamped = max(device.minAvailableVideoZoomFactor, min(factor, device.maxAvailableVideoZoomFactor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
            } catch {
                // best effort, ignore
            }
        }
    }

    func setExposureBias(_ ev: Float) {
        sessionQueue.async { [self] in
            guard let device = currentDevice else { return }
            let clamped = max(device.minExposureTargetBias, min(device.maxExposureTargetBias, ev))
            do {
                try device.lockForConfiguration()
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                // best effort
            }
        }
    }

    /// `point` is in normalized device coordinates (0...1, with origin top-left of the preview).
    func focus(at point: CGPoint) {
        sessionQueue.async { [self] in
            guard let device = currentDevice else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = point
                    device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch {
                // best effort
            }
        }
    }

    // MARK: - Capture

    func capturePhoto(flashMode: CameraFlashMode) async throws -> Data {
        guard session.isRunning else { throw SessionError.notRunning }

        return try await withCheckedThrowingContinuation { [self] (continuation: CheckedContinuation<Data, Error>) in
            sessionQueue.async {
                self.captureContinuation = continuation

                let settings = AVCapturePhotoSettings()
                if self.photoOutput.supportedFlashModes.contains(flashMode.avFlashMode) {
                    settings.flashMode = flashMode.avFlashMode
                }
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    // MARK: - Private

    private func configureSync(position: CameraPosition) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }

        try attachInput(for: position)

        if !session.outputs.contains(where: { $0 === photoOutput }) {
            guard session.canAddOutput(photoOutput) else {
                throw SessionError.configurationFailed
            }
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }

        currentPosition = position
    }

    private func attachInput(for position: CameraPosition) throws {
        guard let device = Self.device(for: position) else {
            throw SessionError.noDevice
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw SessionError.configurationFailed
        }
        session.addInput(input)
        currentInput = input
        currentDevice = device

        // Disable auto-HDR on the live preview to avoid the dim/processed look
        // the user reported. Focus / exposure / white balance remain on
        // continuous-auto (their defaults).
        do {
            try device.lockForConfiguration()
            if device.activeFormat.isVideoHDRSupported {
                device.automaticallyAdjustsVideoHDREnabled = false
                device.isVideoHDREnabled = false
            }
            device.unlockForConfiguration()
        } catch {
            // best effort; preview will still work
        }
    }

    private static func device(for position: CameraPosition) -> AVCaptureDevice? {
        let avPosition: AVCaptureDevice.Position = position == .back ? .back : .front
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraSession {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = captureContinuation
        captureContinuation = nil

        if let error {
            continuation?.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: SessionError.captureFailed)
            return
        }
        continuation?.resume(returning: data)
    }
}

// MARK: - Helpers

private extension CameraFlashMode {
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
}
