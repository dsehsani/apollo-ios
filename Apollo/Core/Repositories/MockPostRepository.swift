//
//  MockPostRepository.swift
//  Apollo
//
//  In-memory stub for SwiftUI previews and unit tests.
//

import Foundation
import UIKit

final class MockPostRepository: PostRepository, @unchecked Sendable {

    enum ForcedState: Sendable {
        case success
        case uploadFails
        case uploadFailsOffline
        case saveFails
    }

    private let forced: ForcedState
    private var callCount = 0

    init(forceState: ForcedState = .success) {
        self.forced = forceState
    }

    // MARK: - Phase 1

    func uploadGradedPhoto(
        image: UIImage,
        capturedAt: Date
    ) async throws -> PendingUploadResult {
        try await Task.sleep(for: .milliseconds(600))
        switch forced {
        case .uploadFails:        throw PostRepositoryError.uploadFailed(reason: "mock")
        case .uploadFailsOffline: throw PostRepositoryError.networkError
        default: break
        }
        let url = URL(string: "https://example.com/posts/mock-\(UUID().uuidString).jpg")!
        return PendingUploadResult(publicURL: url, storagePath: "mock/path.jpg", capturedAt: capturedAt)
    }

    // MARK: - Phase 2

    func commitUsePhoto(
        pending: PendingUploadResult,
        winID: UUID?,
        privateNote: String?
    ) async throws -> PublishedPhotoResult {
        try await Task.sleep(for: .milliseconds(300))
        if forced == .saveFails { throw PostRepositoryError.saveFailed(reason: "mock") }
        callCount += 1
        return PublishedPhotoResult(
            postID:    UUID(),
            photoID:   UUID(),
            position:  callCount - 1,
            totalWins: callCount
        )
    }

    // MARK: - Cancel

    func cancelPendingUpload(_ pending: PendingUploadResult) async {
        // No-op for mock.
    }
}
