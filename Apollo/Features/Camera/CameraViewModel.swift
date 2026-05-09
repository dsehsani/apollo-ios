//
//  CameraViewModel.swift
//  Apollo
//
//  One @Observable view model per screen (Apollo convention). Owns Camera
//  state, permission handling, win selection, capture flow with optimistic
//  count bump, and a small in-memory retry queue for upload failures.
//

import AVFoundation
import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class CameraViewModel {

    enum Phase: Equatable {
        case idle
        case configuring
        case active
        case permissionDenied
        case unsupported
    }

    struct PendingUpload: Identifiable, Sendable {
        let id: UUID
        let winID: UUID?
        let imageData: Data
        let capturedAt: Date
        var attempts: Int
    }

    private let repository: CameraRepository
    let cameraSession: CameraSession

    // UI state
    var phase: Phase = .idle
    var flash: CameraFlashMode = .off
    var position: CameraPosition = .back
    var wins: [Win] = []
    var activeWin: Win?
    var todaySummary: TodayCameraSummary = .empty
    var isWinPickerPresented: Bool = false
    var isCapturePresented: Bool = false
    var isDevelopPresented: Bool = false
    var lastCapturedPhoto: CapturedPhoto?
    var lastCapturedImage: UIImage?
    var pendingUploads: [PendingUpload] = []
    var transientErrorMessage: String?
    var isFlipping: Bool = false

    // Zoom state
    var currentZoom: CGFloat = 1.0
    private var pinchBaseZoom: CGFloat = 1.0
    private static let minZoom: CGFloat = 0.5
    private static let maxZoom: CGFloat = 5.0

    // Focus / exposure UI
    var focusUIPoint: CGPoint?
    var exposureBias: Float = 0
    private var focusDismissTask: Task<Void, Never>?

    // Capture animation
    var shutterPressed: Bool = false

    init(
        repository: CameraRepository = MockCameraRepository(),
        cameraSession: CameraSession = CameraSession()
    ) {
        self.repository = repository
        self.cameraSession = cameraSession
    }

    var isAtMaxPhotos: Bool {
        todaySummary.photoCount >= MaxPhotosPerDay
    }

    var canCapture: Bool {
        phase == .active && !isAtMaxPhotos
    }

    var isMirrored: Bool { position == .front }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await bootstrap() }
    }

    func onDisappear() {
        cameraSession.stop()
    }

    private func bootstrap() async {
        async let permission: Bool = requestPermission()
        async let winsResult: [Win] = fetchWinsSafely()
        async let activeID: UUID? = fetchActiveWinIDSafely()
        async let summaryResult: TodayCameraSummary = fetchSummarySafely()

        let granted = await permission
        wins = await winsResult
        let aid = await activeID
        todaySummary = await summaryResult
        activeWin = wins.first(where: { $0.id == aid }) ?? wins.first

        guard granted else {
            phase = .permissionDenied
            return
        }

        phase = .configuring
        do {
            try await cameraSession.configure(position: position)
            await cameraSession.start()
            phase = .active
        } catch {
            phase = .unsupported
            transientErrorMessage = "Camera couldn't start."
        }
    }

    private func requestPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private func fetchWinsSafely() async -> [Win] {
        (try? await repository.fetchAllWins()) ?? []
    }

    private func fetchActiveWinIDSafely() async -> UUID? {
        (try? await repository.fetchActiveWinID()) ?? nil
    }

    private func fetchSummarySafely() async -> TodayCameraSummary {
        (try? await repository.fetchTodaySummary()) ?? .empty
    }

    // MARK: - Permission

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Win selection

    func openWinPicker() {
        guard !wins.isEmpty else { return }
        isWinPickerPresented = true
    }

    func selectWin(_ win: Win) {
        activeWin = win
        isWinPickerPresented = false
        Task { try? await repository.setActiveWinID(win.id) }
    }

    // MARK: - Flash / flip / zoom / focus

    func cycleFlash() {
        flash = flash.next
    }

    func flipCamera(reduceMotion: Bool) {
        guard !isFlipping else { return }
        isFlipping = true
        let next = position.toggled
        Task {
            do {
                try await cameraSession.setPosition(next)
                position = next
                currentZoom = 1.0
            } catch {
                transientErrorMessage = "Couldn't switch cameras."
            }
            if reduceMotion {
                isFlipping = false
            } else {
                try? await Task.sleep(nanoseconds: 300_000_000)
                isFlipping = false
            }
        }
    }

    func pinchChanged(scale: CGFloat) {
        let target = clampZoom(pinchBaseZoom * scale)
        currentZoom = target
        cameraSession.setZoom(target)
    }

    func pinchEnded() {
        pinchBaseZoom = currentZoom
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        max(Self.minZoom, min(Self.maxZoom, value))
    }

    func tapToFocus(devicePoint: CGPoint, layerPoint: CGPoint) {
        cameraSession.focus(at: devicePoint)
        cameraSession.setExposureBias(0)
        focusUIPoint = layerPoint
        exposureBias = 0
        scheduleFocusUIDismiss()
    }

    func setExposureBias(_ ev: Float) {
        let clamped = max(-2, min(2, ev))
        exposureBias = clamped
        cameraSession.setExposureBias(clamped)
        scheduleFocusUIDismiss()
    }

    func scheduleFocusUIDismissPublic() {
        scheduleFocusUIDismiss()
    }

    private func scheduleFocusUIDismiss() {
        focusDismissTask?.cancel()
        focusDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.focusUIPoint = nil
        }
    }

    // Legacy alias kept so existing callsites still compile during transition
    func focusAt(_ normalizedPoint: CGPoint) {
        cameraSession.focus(at: normalizedPoint)
    }

    // MARK: - Capture

    func capture() {
        guard canCapture else { return }
        let winID = activeWin?.id
        let mode = flash

        withAnimation(.spring(response: 0.1)) {
            shutterPressed = true
        }

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.1)) {
                    self.shutterPressed = false
                }
            }

            do {
                let data = try await self.cameraSession.capturePhoto(flashMode: mode)
                let image = UIImage(data: data)
                await MainActor.run {
                    self.lastCapturedImage = image
                    self.todaySummary.photoCount = min(self.todaySummary.photoCount + 1, MaxPhotosPerDay)
                    self.isCapturePresented = true
                }
                self.startUpload(data: data, winID: winID)
            } catch {
                await MainActor.run {
                    self.transientErrorMessage = "Couldn't take photo. Try again."
                }
            }
        }
    }

    private func startUpload(data: Data, winID: UUID?) {
        let upload = PendingUpload(
            id: UUID(),
            winID: winID,
            imageData: data,
            capturedAt: Date(),
            attempts: 0
        )
        Task { [weak self] in
            await self?.attemptUpload(upload)
        }
    }

    private func attemptUpload(_ upload: PendingUpload) async {
        var work = upload
        let maxAttempts = 3

        while work.attempts < maxAttempts {
            work.attempts += 1
            do {
                let result = try await repository.uploadPhoto(
                    winID: work.winID,
                    imageData: work.imageData,
                    capturedAt: work.capturedAt
                )
                lastCapturedPhoto = result
                if let grid = result.updatedGridURL {
                    todaySummary.gridURL = grid
                }
                todaySummary.photoCount = result.newPhotoCount
                pendingUploads.removeAll { $0.id == work.id }
                return
            } catch {
                let backoff = UInt64(pow(2.0, Double(work.attempts))) * 500_000_000
                try? await Task.sleep(nanoseconds: backoff)
            }
        }

        if !pendingUploads.contains(where: { $0.id == work.id }) {
            pendingUploads.append(work)
        }
    }

    // MARK: - Helpers

    func dismissCapture() {
        isCapturePresented = false
        lastCapturedImage = nil
    }

    func presentDevelop() {
        isCapturePresented = false
        isDevelopPresented = true
    }

    func retakeFromDevelop() {
        isDevelopPresented = false
        lastCapturedImage = nil
    }

    func confirmDevelop() {
        isDevelopPresented = false
        lastCapturedImage = nil
    }

    func clearTransientError() {
        transientErrorMessage = nil
    }
}
