//
//  CameraViewModel.swift
//  Apollo
//
//  Orchestrates the full capture-review-upload-commit flow.
//
//  Shutter tap:
//    1. AVFoundation captures raw photo data.
//    2. CaptureReview is shown immediately (<200 ms).
//    3. Background Task grades (Core Image) + uploads to Supabase Storage.
//
//  Use Photo tap:
//    - If upload still in-flight: waits for its result then commits.
//    - If upload ready: commits immediately via publish_photo RPC.
//    - If upload failed online: automatically retries upload then commits.
//    - On success: fires feed/profile refresh notifications and calls onClose.
//
//  Retake tap:
//    - Cancels in-flight upload Task.
//    - Deletes orphaned storage object if upload had already succeeded.
//    - Resets all capture state and restarts the live preview.
//
//  Offline path:
//    - If upload fails with PostRepositoryError.networkError, item is silently
//      added to UploadQueue. When the network is restored, queue retries
//      upload + commit automatically without user interaction.
//

import AVFoundation
import Foundation
import Observation
import os
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

    enum UploadState: Equatable {
        case idle
        case uploading
        case ready
        case failedOnline  // toast shown; Use Photo taps trigger a retry
        case queuedOffline // silent retry when network returns
        case committing
    }

    // MARK: - Dependencies

    private let repository: CameraRepository
    private let postRepository: PostRepository
    let cameraSession: CameraSession
    private let uploadQueue: UploadQueue

    // MARK: - Camera state

    var phase: Phase = .idle
    var flash: CameraFlashMode = .off
    var position: CameraPosition = .back
    var wins: [Win] = []
    var activeWin: Win?
    var todaySummary: TodayCameraSummary = .empty
    var isWinPickerPresented: Bool = false
    var isFlipping: Bool = false
    var transientErrorMessage: String?

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

    // MARK: - Capture review state

    var isCaptureReviewPresented: Bool = false
    var lastCapturedImage: UIImage?
    var captureTime: Date?
    var privateNote: String = ""
    var uploadState: UploadState = .idle

    /// Set true when a commit succeeds; CameraView uses this to also dismiss itself.
    var didCommitPhoto: Bool = false

    /// Result of phase-1 upload; nil until upload completes.
    var pendingUpload: PendingUploadResult?

    /// Day number label for the review screen ("Day X.").
    var dayNumber: Int { min(todaySummary.photoCount, MaxPhotosPerDay) }

    // MARK: - Private upload task

    private var uploadTask: Task<PendingUploadResult, Error>?

    // MARK: - Init

    init(
        repository: CameraRepository = MockCameraRepository(),
        postRepository: PostRepository = MockPostRepository(),
        cameraSession: CameraSession = CameraSession()
    ) {
        self.repository = repository
        self.postRepository = postRepository
        self.cameraSession = cameraSession
        self.uploadQueue = UploadQueue()
        self.uploadQueue.start()
    }

    // MARK: - Derived

    var isAtMaxPhotos: Bool { todaySummary.photoCount >= MaxPhotosPerDay }
    var canCapture: Bool { phase == .active && !isAtMaxPhotos }
    var isMirrored: Bool { position == .front }

    // MARK: - Lifecycle

    func onAppear() {
        Analytics.track(.cameraOpened)
        setupOfflineQueueCallback()
        Task { await bootstrap() }
    }

    func onDisappear() {
        cameraSession.stop()
        uploadQueue.stop()
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
        case .authorized:   return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default:             return false
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

    func openWinPicker() { isWinPickerPresented = true }

    func selectWin(_ win: Win) {
        activeWin = win
        isWinPickerPresented = false
        Task { try? await repository.setActiveWinID(win.id) }
    }

    // MARK: - Flash / flip / zoom / focus

    func cycleFlash() { flash = flash.next }

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

    func pinchEnded() { pinchBaseZoom = currentZoom }

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

    func scheduleFocusUIDismissPublic() { scheduleFocusUIDismiss() }

    private func scheduleFocusUIDismiss() {
        focusDismissTask?.cancel()
        focusDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            self?.focusUIPoint = nil
        }
    }

    // Legacy alias kept so callsites still compile.
    func focusAt(_ normalizedPoint: CGPoint) {
        cameraSession.focus(at: normalizedPoint)
    }

    // MARK: - Capture

    func capture() {
        guard canCapture else { return }
        Analytics.track(.shutterTapped)
        let mode = flash

        withAnimation(.spring(response: 0.1)) { shutterPressed = true }

        Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                withAnimation(.spring(response: 0.1)) { self.shutterPressed = false }
            }

            do {
                CameraLog.log.debug("capture: calling capturePhoto")
                let data = try await self.cameraSession.capturePhoto(flashMode: mode)
                CameraLog.log.debug("capture: got \(data.count) bytes from AVFoundation")

                let image = UIImage(data: data)
                let now = Date()

                await MainActor.run {
                    self.lastCapturedImage = image
                    self.captureTime = now
                    self.todaySummary.photoCount = min(self.todaySummary.photoCount + 1, MaxPhotosPerDay)
                    self.isCaptureReviewPresented = true
                    self.cameraSession.stop()

                    if let image {
                        CameraLog.log.debug("capture: UIImage created, starting background upload")
                        self.uploadState = .uploading
                        self.startBackgroundUpload(image: image, capturedAt: now)
                    } else {
                        // AVFoundation returned data but UIImage couldn't decode it.
                        CameraLog.log.error("capture: UIImage(data:) returned nil for \(data.count) bytes")
                        self.uploadState = .failedOnline
                        self.transientErrorMessage = "Couldn't process photo. Tap to retry."
                    }
                }
            } catch {
                CameraLog.log.error("capture: capturePhoto threw: \(error.localizedDescription)")
                await MainActor.run {
                    self.transientErrorMessage = "Couldn't take photo. Try again."
                }
            }
        }
    }

    // MARK: - Background upload

    private func startBackgroundUpload(image: UIImage, capturedAt: Date) {
        uploadTask?.cancel()
        uploadState = .uploading

        let task = Task<PendingUploadResult, Error> { [repo = postRepository] in
            return try await repo.uploadGradedPhoto(image: image, capturedAt: capturedAt)
        }
        uploadTask = task

        Task { [weak self] in
            guard let self else { return }
            do {
                let pending = try await task.value
                guard !Task.isCancelled else {
                    CameraLog.log.debug("startBackgroundUpload: upload task cancelled (retake)")
                    return
                }
                CameraLog.log.debug("startBackgroundUpload: upload succeeded, path=\(pending.storagePath)")
                self.pendingUpload = pending
                self.uploadState = .ready
            } catch is CancellationError {
                CameraLog.log.debug("startBackgroundUpload: CancellationError (retake path)")
            } catch PostRepositoryError.networkError {
                CameraLog.log.info("startBackgroundUpload: network error — queuing offline")
                if let img = self.lastCapturedImage, let time = self.captureTime {
                    self.uploadQueue.enqueue(UploadQueue.QueuedItem(
                        image: img,
                        capturedAt: time,
                        winID: self.activeWin?.id,
                        privateNote: self.privateNote.isEmpty ? nil : self.privateNote
                    ))
                }
                self.uploadState = .queuedOffline
                self.dismissReviewAfterOfflineQueue()
            } catch {
                CameraLog.log.error("startBackgroundUpload: upload failed: \(error.localizedDescription)")
                self.uploadState = .failedOnline
                self.transientErrorMessage = "Couldn't save your photo. Tap to retry."
            }
        }
    }

    private func dismissReviewAfterOfflineQueue() {
        isCaptureReviewPresented = false
        lastCapturedImage = nil
        captureTime = nil
        privateNote = ""
        uploadState = .idle
        Task { [weak self] in await self?.cameraSession.start() }
    }

    // MARK: - Use Photo

    func usePhoto() {
        guard uploadState != .committing else {
            CameraLog.log.debug("usePhoto: already committing, ignoring tap")
            return
        }
        Analytics.track(.usePhotoTapped)
        if !privateNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Analytics.track(.privateNoteAdded)
        }

        Task { [weak self] in
            guard let self else { return }

            // ── State: uploading ─────────────────────────────────────────────
            // Wait for the in-flight upload task to resolve.
            if self.uploadState == .uploading, let task = self.uploadTask {
                CameraLog.log.debug("usePhoto: upload still in-flight, awaiting task")
                do {
                    let pending = try await task.value
                    self.pendingUpload = pending
                    self.uploadState = .ready
                    CameraLog.log.debug("usePhoto: upload completed while waiting")
                } catch is CancellationError {
                    // The upload task was cancelled (e.g. Retake during the await).
                    // Do not show an error — the user already chose to retake.
                    CameraLog.log.debug("usePhoto: CancellationError during await — user retook")
                    return
                } catch PostRepositoryError.networkError {
                    CameraLog.log.info("usePhoto: network error while awaiting upload — queueing offline")
                    self.uploadQueue.enqueue(UploadQueue.QueuedItem(
                        image: self.lastCapturedImage ?? UIImage(),
                        capturedAt: self.captureTime ?? .now,
                        winID: self.activeWin?.id,
                        privateNote: self.privateNote.isEmpty ? nil : self.privateNote
                    ))
                    self.dismissReviewAfterOfflineQueue()
                    return
                } catch {
                    CameraLog.log.error("usePhoto: upload error while awaiting: \(error.localizedDescription)")
                    self.uploadState = .failedOnline
                    self.transientErrorMessage = "Couldn't save your photo. Tap to retry."
                    return
                }
            }

            // ── State: failedOnline ──────────────────────────────────────────
            // Upload previously failed. Treat this tap as "retry + commit".
            if self.uploadState == .failedOnline {
                CameraLog.log.info("usePhoto: retrying failed upload before commit")
                guard let image = self.lastCapturedImage, let capturedAt = self.captureTime else {
                    CameraLog.log.error("usePhoto: failedOnline but no image/captureTime — cannot retry")
                    self.transientErrorMessage = "Couldn't save your photo. Try again."
                    return
                }
                self.transientErrorMessage = nil
                self.uploadState = .uploading

                do {
                    let pending = try await self.postRepository.uploadGradedPhoto(
                        image: image, capturedAt: capturedAt
                    )
                    self.pendingUpload = pending
                    self.uploadState = .ready
                    CameraLog.log.debug("usePhoto: retry upload succeeded")
                } catch PostRepositoryError.networkError {
                    CameraLog.log.info("usePhoto: retry upload — network still unavailable, queueing offline")
                    self.uploadQueue.enqueue(UploadQueue.QueuedItem(
                        image: image,
                        capturedAt: capturedAt,
                        winID: self.activeWin?.id,
                        privateNote: self.privateNote.isEmpty ? nil : self.privateNote
                    ))
                    self.dismissReviewAfterOfflineQueue()
                    return
                } catch {
                    CameraLog.log.error("usePhoto: retry upload failed: \(error.localizedDescription)")
                    self.uploadState = .failedOnline
                    self.transientErrorMessage = "Couldn't save your photo. Tap to retry."
                    return
                }
            }

            // ── State: must be .ready now ────────────────────────────────────
            guard self.uploadState == .ready, let pending = self.pendingUpload else {
                CameraLog.log.error("usePhoto: unexpected state=\(String(describing: self.uploadState)) pending=\(self.pendingUpload == nil ? "nil" : "set") — showing error")
                self.transientErrorMessage = "Couldn't save your photo. Try again."
                return
            }

            // ── Commit ───────────────────────────────────────────────────────
            CameraLog.log.debug("usePhoto: committing — path=\(pending.storagePath)")
            self.uploadState = .committing
            do {
                let note = self.privateNote.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await self.postRepository.commitUsePhoto(
                    pending: pending,
                    winID: self.activeWin?.id,
                    privateNote: note.isEmpty ? nil : note
                )
                CameraLog.log.info("usePhoto: commit succeeded postID=\(result.postID) photoID=\(result.photoID) totalWins=\(result.totalWins)")
                NotificationCenter.default.post(name: .apolloFeedShouldRefresh, object: nil)
                NotificationCenter.default.post(name: .apolloProfileShouldRefresh, object: nil)
                NotificationCenter.default.post(
                    name: .apolloPostCommitted,
                    object: nil,
                    userInfo: ["totalWins": result.totalWins]
                )
                self.resetAfterCommit()
            } catch {
                CameraLog.log.error("usePhoto: commit failed: \(error.localizedDescription)")
                self.uploadState = .ready
                let reason: String
                switch error {
                case PostRepositoryError.saveFailed(let r):    reason = r
                case PostRepositoryError.uploadFailed(let r):  reason = r
                case PostRepositoryError.unauthenticated:      reason = "unauthenticated"
                case PostRepositoryError.compressionFailed:    reason = "compression failed"
                case PostRepositoryError.networkError:         reason = "network"
                default:                                       reason = error.localizedDescription
                }
                self.transientErrorMessage = "Save failed: \(reason)"
            }
        }
    }

    private func resetAfterCommit() {
        pendingUpload = nil
        uploadTask = nil
        uploadState = .idle
        lastCapturedImage = nil
        captureTime = nil
        privateNote = ""
        didCommitPhoto = true
        isCaptureReviewPresented = false
    }

    // MARK: - Retake

    func retakePhoto() {
        Analytics.track(.retakeTapped)
        CameraLog.log.debug("retakePhoto: cancelling upload, clearing state")
        let hadPending = pendingUpload

        uploadTask?.cancel()
        uploadTask = nil
        uploadState = .idle

        if let pending = hadPending {
            Task { [repo = postRepository] in await repo.cancelPendingUpload(pending) }
        }

        pendingUpload = nil
        lastCapturedImage = nil
        captureTime = nil
        privateNote = ""
        transientErrorMessage = nil
        todaySummary.photoCount = max(0, todaySummary.photoCount - 1)
        isCaptureReviewPresented = false

        Task { [weak self] in await self?.cameraSession.start() }
    }

    // MARK: - Retry upload (toast action)

    func retryUpload() {
        guard let image = lastCapturedImage, let capturedAt = captureTime else {
            CameraLog.log.error("retryUpload: no image or captureTime to retry with")
            return
        }
        CameraLog.log.debug("retryUpload: restarting upload")
        transientErrorMessage = nil
        startBackgroundUpload(image: image, capturedAt: capturedAt)
    }

    // MARK: - Offline queue

    private func setupOfflineQueueCallback() {
        uploadQueue.onNetworkRestored = { [weak self] items in
            guard let self else { return }
            Task { await self.drainOfflineQueue(items) }
        }
    }

    private func drainOfflineQueue(_ items: [UploadQueue.QueuedItem]) async {
        CameraLog.log.info("drainOfflineQueue: draining \(items.count) queued item(s)")
        for item in items {
            do {
                let pending = try await postRepository.uploadGradedPhoto(
                    image: item.image, capturedAt: item.capturedAt
                )
                do {
                    let result = try await postRepository.commitUsePhoto(
                        pending: pending,
                        winID: item.winID,
                        privateNote: item.privateNote
                    )
                    CameraLog.log.info("drainOfflineQueue: committed postID=\(result.postID)")
                    NotificationCenter.default.post(name: .apolloFeedShouldRefresh, object: nil)
                    NotificationCenter.default.post(name: .apolloProfileShouldRefresh, object: nil)
                } catch {
                    CameraLog.log.error("drainOfflineQueue: commit failed for queued item: \(error.localizedDescription)")
                }
            } catch {
                CameraLog.log.error("drainOfflineQueue: upload failed for queued item: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Misc

    func clearTransientError() { transientErrorMessage = nil }
}
