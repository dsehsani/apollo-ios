//
//  SupabaseCameraRepository.swift
//  Apollo
//
//  Supabase-backed CameraRepository. All methods are stubs awaiting backend
//  tables. Endpoint shape matches Camera PRD §8 (POST /photos/capture).
//

import Foundation

nonisolated final class SupabaseCameraRepository: CameraRepository, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // GET /wins?user_id=...
    func fetchAllWins() async throws -> [Win] {
        // TODO: select id, name, current_streak from `wins` where user_id = currentUserID.
        throw CameraRepositoryError.unknown
    }

    // GET /wins/active?user_id=...
    func fetchActiveWinID() async throws -> UUID? {
        // TODO: select active_win_id from `users` where id = currentUserID.
        throw CameraRepositoryError.unknown
    }

    // PATCH /users/:id { active_win_id }
    func setActiveWinID(_ id: UUID?) async throws {
        // TODO: update users set active_win_id = id where id = currentUserID.
        throw CameraRepositoryError.unknown
    }

    // GET /posts/today?user_id=...
    func fetchTodaySummary() async throws -> TodayCameraSummary {
        // TODO: select photo_count + grid_url from today's `posts` row for currentUserID.
        throw CameraRepositoryError.unknown
    }

    // POST /photos/capture — see PRD §8
    // Request:  user_id, win_id, image_data (base64 JPEG), captured_at (ISO8601)
    // Response: photo_id, raw_url, updated_grid_url, updated_main_url, new_photo_count
    func uploadPhoto(
        winID: UUID?,
        imageData: Data,
        capturedAt: Date
    ) async throws -> CapturedPhoto {
        // TODO: multipart upload to /functions/v1/photos-capture; on 4xx map to
        // CameraRepositoryError.forbidden / .rateLimited as appropriate.
        throw CameraRepositoryError.unknown
    }
}
