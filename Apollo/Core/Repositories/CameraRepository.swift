//
//  CameraRepository.swift
//  Apollo
//
//  Abstraction over the Camera data source. The Camera view model talks only
//  to this protocol; the concrete implementation can be swapped between
//  MockCameraRepository and SupabaseCameraRepository without touching the UI.
//

import Foundation

protocol CameraRepository: Sendable {
    var currentUserID: UUID { get }

    func fetchAllWins() async throws -> [Win]
    func fetchActiveWinID() async throws -> UUID?
    func setActiveWinID(_ id: UUID?) async throws
    func fetchTodaySummary() async throws -> TodayCameraSummary
    func uploadPhoto(
        winID: UUID?,
        imageData: Data,
        capturedAt: Date
    ) async throws -> CapturedPhoto
}
