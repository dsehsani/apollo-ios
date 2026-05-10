//
//  PostRepository.swift
//  Apollo
//
//  Protocol + supporting types for the two-phase photo-posting flow.
//
//  Phase 1 — uploadGradedPhoto: grade via Core Image, compress to JPEG 0.8,
//             upload to Supabase Storage, return a PendingUploadResult with
//             the public URL + storage path ready for phase 2.
//
//  Phase 2 — commitUsePhoto: atomically write to `posts`, `photos`,
//             `win_completions`, increment `users.total_wins` via the
//             `publish_photo` RPC, and optionally insert a private note.
//
//  cancelPendingUpload: removes an orphaned storage object if the user
//  retakes before committing to the database.
//

import UIKit

// MARK: - Progress phases

enum PostingProgress: Sendable {
    /// Applying Core Image grade + encoding JPEG.
    case compressing
    /// Uploading JPEG bytes to Supabase Storage.
    case uploading
    /// Writing posts / photos / win_completions rows and incrementing counters.
    case saving
}

// MARK: - Phase 1 result

struct PendingUploadResult: Sendable {
    let publicURL: URL
    let storagePath: String
    let capturedAt: Date
}

// MARK: - Phase 2 result

struct PublishedPhotoResult: Sendable {
    let postID: UUID
    let photoID: UUID
    let position: Int
    /// User's updated lifetime wins count after this photo.
    let totalWins: Int
}

// MARK: - Errors

enum PostRepositoryError: Error, Sendable {
    case unauthenticated
    case compressionFailed
    /// Upload failed due to a transient network error (show offline toast).
    case networkError
    case uploadFailed(reason: String)
    case saveFailed(reason: String)
    case unknown
}

// MARK: - Protocol

protocol PostRepository: Sendable {

    /// Phase 1: apply Core Image grade, compress to JPEG 0.8, upload to storage.
    ///
    /// Returns a `PendingUploadResult` the caller must either pass to
    /// `commitUsePhoto` or cancel via `cancelPendingUpload`.
    func uploadGradedPhoto(
        image: UIImage,
        capturedAt: Date
    ) async throws -> PendingUploadResult

    /// Phase 2: atomically write post + photo + win_completion + optional note.
    ///
    /// Must only be called after a successful `uploadGradedPhoto`.
    func commitUsePhoto(
        pending: PendingUploadResult,
        winID: UUID?,
        privateNote: String?
    ) async throws -> PublishedPhotoResult

    /// Removes the orphaned storage object when the user retakes before committing.
    func cancelPendingUpload(_ pending: PendingUploadResult) async
}
