//
//  SupabasePostRepository.swift
//  Apollo
//
//  Supabase-backed PostRepository. Implements the two-phase capture flow:
//
//  Phase 1 — uploadGradedPhoto: applies Core Image grade, compresses to
//    JPEG 0.8, uploads to the "posts" Storage bucket, and returns the
//    public URL so the capture review screen can display it immediately.
//
//  Phase 2 — commitUsePhoto: atomically calls the `publish_photo` Postgres
//    RPC (upserts today's post, inserts photo + win_completion, increments
//    users.total_wins), then appends an optional private note.
//
//  Upload path:  posts/{userID}/{uuid}.jpg
//  Bucket:       posts  (jpeg/png/webp/heic, 10 MB max)
//

import Foundation
import os
import Supabase
import UIKit

final class SupabasePostRepository: PostRepository, @unchecked Sendable {

    private let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID

        // Warn immediately if the repository's user ID doesn't match the
        // authenticated session — this would cause every RLS-protected write
        // to fail silently.
        let authUID = supabase.auth.currentUser?.id
        // #region agent log
        DebugFileLog.log("H1", "SupabasePostRepository.init", "auth-vs-currentUserID compare", [
            "currentUserID": currentUserID.uuidString.lowercased(),
            "authUID": authUID?.uuidString.lowercased() ?? "<nil>",
            "match": authUID == currentUserID,
            "isAuthenticated": supabase.auth.currentUser != nil,
        ])
        // #endregion
        if authUID != currentUserID {
            CameraLog.log.error(
                "SupabasePostRepository: currentUserID \(currentUserID) != auth.uid() \(String(describing: authUID)) — uploads will fail RLS checks"
            )
        } else {
            CameraLog.log.debug("SupabasePostRepository: init with userID=\(currentUserID)")
        }
    }

    // MARK: - Phase 1: grade + upload

    func uploadGradedPhoto(
        image: UIImage,
        capturedAt: Date
    ) async throws -> PendingUploadResult {
        // Grade → JPEG
        let graded = CameraImageGrader.grade(image)
        guard let jpegData = graded.jpegData(compressionQuality: 0.8) else {
            CameraLog.log.error("uploadGradedPhoto: jpegData(compressionQuality:) returned nil")
            throw PostRepositoryError.compressionFailed
        }

        let storagePath = "\(currentUserID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        CameraLog.log.debug("uploadGradedPhoto: uploading \(jpegData.count) bytes to posts/\(storagePath)")

        do {
            try await supabase.storage
                .from("posts")
                .upload(
                    path: storagePath,
                    file: jpegData,
                    options: FileOptions(contentType: "image/jpeg", upsert: false)
                )
            CameraLog.log.debug("uploadGradedPhoto: storage upload succeeded")
            // #region agent log
            DebugFileLog.log("H4", "SupabasePostRepository.uploadGradedPhoto", "storage upload OK", [
                "storagePath": storagePath,
                "byteCount": jpegData.count,
            ])
            // #endregion
        } catch {
            let ns = error as NSError
            CameraLog.log.error(
                "uploadGradedPhoto: storage upload failed — domain=\(ns.domain) code=\(ns.code) localizedDescription=\(ns.localizedDescription) userInfo=\(ns.userInfo)"
            )
            // #region agent log
            DebugFileLog.log("H4", "SupabasePostRepository.uploadGradedPhoto", "storage upload FAILED", [
                "storagePath": storagePath,
                "byteCount": jpegData.count,
                "errDomain": ns.domain,
                "errCode": ns.code,
                "errDesc": ns.localizedDescription,
                "errUserInfo": String(describing: ns.userInfo),
            ])
            // #endregion
            if isNetworkError(error) { throw PostRepositoryError.networkError }
            let reason = "[storage \(ns.code)] \(ns.localizedDescription)"
            throw PostRepositoryError.uploadFailed(reason: reason)
        }

        let publicURL: URL
        do {
            publicURL = try supabase.storage
                .from("posts")
                .getPublicURL(path: storagePath)
            CameraLog.log.debug("uploadGradedPhoto: publicURL=\(publicURL.absoluteString)")
        } catch {
            CameraLog.log.error("uploadGradedPhoto: getPublicURL failed: \(error.localizedDescription)")
            try? await supabase.storage.from("posts").remove(paths: [storagePath])
            throw PostRepositoryError.uploadFailed(reason: "[publicURL] \(error.localizedDescription)")
        }

        return PendingUploadResult(publicURL: publicURL, storagePath: storagePath, capturedAt: capturedAt)
    }

    // MARK: - Phase 2: DB commit

    func commitUsePhoto(
        pending: PendingUploadResult,
        winID: UUID?,
        privateNote: String?
    ) async throws -> PublishedPhotoResult {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        dateFmt.timeZone   = TimeZone(identifier: "UTC")!
        let postDateStr = dateFmt.string(from: pending.capturedAt)

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let capturedAtStr = iso.string(from: pending.capturedAt)

        let captionText = privateNote.flatMap {
            let t = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        let params = PublishPhotoParams(
            p_user_id:     currentUserID.uuidString.lowercased(),
            p_caption:     captionText,
            p_raw_url:     pending.publicURL.absoluteString,
            p_win_id:      winID?.uuidString.lowercased(),
            p_captured_at: capturedAtStr,
            p_post_date:   postDateStr
        )

        CameraLog.log.debug(
            "commitUsePhoto: calling publish_photo RPC userID=\(params.p_user_id) postDate=\(postDateStr) winID=\(winID?.uuidString ?? "nil")"
        )
        // #region agent log
        DebugFileLog.log("H3", "SupabasePostRepository.commitUsePhoto", "calling publish_photo RPC", [
            "p_user_id": params.p_user_id,
            "p_win_id": params.p_win_id ?? "<nil>",
            "p_post_date": params.p_post_date,
            "p_captured_at": params.p_captured_at,
            "p_raw_url": params.p_raw_url,
        ])
        // #endregion

        let responseData: Data
        do {
            let res = try await supabase
                .rpc("publish_photo", params: params)
                .execute()
            responseData = res.data
        } catch {
            let ns = error as NSError
            CameraLog.log.error(
                "commitUsePhoto: RPC network/auth error — domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription) userInfo=\(ns.userInfo)"
            )
            // #region agent log
            DebugFileLog.log("H3", "SupabasePostRepository.commitUsePhoto", "RPC threw", [
                "errDomain": ns.domain,
                "errCode": ns.code,
                "errDesc": ns.localizedDescription,
                "errUserInfo": String(describing: ns.userInfo),
                "errType": String(describing: type(of: error)),
            ])
            // #endregion
            try? await supabase.storage.from("posts").remove(paths: [pending.storagePath])
            let reason = "[RPC \(ns.code)] \(ns.localizedDescription)"
            throw PostRepositoryError.saveFailed(reason: reason)
        }

        // Log the raw body so we can see exactly what the server returned.
        let rawBody = String(data: responseData, encoding: .utf8) ?? "<non-UTF8 data, \(responseData.count) bytes>"
        CameraLog.log.debug("commitUsePhoto: RPC raw response: \(rawBody)")
        // #region agent log
        DebugFileLog.log("H2", "SupabasePostRepository.commitUsePhoto", "RPC raw response body", [
            "rawBody": rawBody,
            "byteCount": responseData.count,
        ])
        // #endregion

        let decoded: PublishPhotoResponse
        do {
            decoded = try JSONDecoder().decode(PublishPhotoResponse.self, from: responseData)
            CameraLog.log.info(
                "commitUsePhoto: decoded — postID=\(decoded.post_id) photoID=\(decoded.photo_id) position=\(decoded.position) totalWins=\(decoded.total_wins)"
            )
            // #region agent log
            DebugFileLog.log("H2", "SupabasePostRepository.commitUsePhoto", "decode OK", [
                "post_id": decoded.post_id.uuidString,
                "photo_id": decoded.photo_id.uuidString,
                "position": decoded.position,
                "total_wins": decoded.total_wins,
            ])
            // #endregion
        } catch {
            CameraLog.log.error(
                "commitUsePhoto: JSON decode failed — error=\(error) rawBody=\(rawBody)"
            )
            // #region agent log
            DebugFileLog.log("H2", "SupabasePostRepository.commitUsePhoto", "decode FAILED", [
                "rawBody": rawBody,
                "decodeErr": String(describing: error),
            ])
            // #endregion
            try? await supabase.storage.from("posts").remove(paths: [pending.storagePath])
            let preview = String(rawBody.prefix(220))
            throw PostRepositoryError.saveFailed(reason: "[decode] body=\(preview)")
        }

        // Insert private note if provided (best-effort — does not abort the post).
        if let note = privateNote?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            let noteParams = PostNoteInsert(
                post_id:   decoded.post_id.uuidString.lowercased(),
                user_id:   currentUserID.uuidString.lowercased(),
                note_text: String(note.prefix(500))
            )
            do {
                try await supabase
                    .from("post_notes")
                    .insert(noteParams)
                    .execute()
                CameraLog.log.debug("commitUsePhoto: private note inserted")
            } catch {
                CameraLog.log.error("commitUsePhoto: private note insert failed (non-fatal): \(error.localizedDescription)")
            }
        }

        return PublishedPhotoResult(
            postID:    decoded.post_id,
            photoID:   decoded.photo_id,
            position:  decoded.position,
            totalWins: decoded.total_wins
        )
    }

    // MARK: - Cancel (retake path)

    func cancelPendingUpload(_ pending: PendingUploadResult) async {
        CameraLog.log.debug("cancelPendingUpload: removing \(pending.storagePath)")
        do {
            try await supabase.storage.from("posts").remove(paths: [pending.storagePath])
        } catch {
            CameraLog.log.error("cancelPendingUpload: remove failed (non-fatal): \(error.localizedDescription)")
        }
    }

    // MARK: - Private types

    /// PostgREST resolves RPC overloads by the set of JSON keys present in the
    /// body. Swift's compiler-synthesized `Encodable` uses `encodeIfPresent` for
    /// `Optional` fields, which OMITS nil values entirely — that makes the
    /// resolver fail with "Could not find the function …" because the keys
    /// `p_caption` / `p_win_id` are missing. We override `encode(to:)` so nil
    /// fields are written as JSON `null` and all 6 keys are always present.
    private struct PublishPhotoParams: Encodable {
        let p_user_id:     String
        let p_caption:     String?
        let p_raw_url:     String
        let p_win_id:      String?
        let p_captured_at: String
        let p_post_date:   String

        enum CodingKeys: String, CodingKey {
            case p_user_id, p_caption, p_raw_url, p_win_id, p_captured_at, p_post_date
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(p_user_id,     forKey: .p_user_id)
            try c.encode(p_caption,     forKey: .p_caption)     // nil → null
            try c.encode(p_raw_url,     forKey: .p_raw_url)
            try c.encode(p_win_id,      forKey: .p_win_id)      // nil → null
            try c.encode(p_captured_at, forKey: .p_captured_at)
            try c.encode(p_post_date,   forKey: .p_post_date)
        }
    }

    private struct PublishPhotoResponse: Decodable {
        let post_id:    UUID
        let photo_id:   UUID
        let position:   Int
        let total_wins: Int
    }

    private struct PostNoteInsert: Encodable {
        let post_id:   String
        let user_id:   String
        let note_text: String
    }

    // MARK: - Helpers

    private func isNetworkError(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain ||
               ns.code == NSURLErrorNotConnectedToInternet ||
               ns.code == NSURLErrorNetworkConnectionLost
    }
}
