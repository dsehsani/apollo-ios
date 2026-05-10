//
//  MockCameraRepository.swift
//  Apollo
//
//  In-memory fixtures used while the real wins/photos schema is being built.
//  Win names match the Figma frame "Set Wins" so designers and devs see the
//  same copy in app and in screenshots.
//

import Foundation

nonisolated final class MockCameraRepository: CameraRepository, @unchecked Sendable {

    enum ForcedState: Sendable {
        case withWins
        case noWins
        case maxedOut
        case error
    }

    let currentUserID: UUID
    private let forced: ForcedState
    private let lock = NSLock()
    private var wins: [Win]
    private var activeWinID: UUID?
    private var summary: TodayCameraSummary

    init(forceState: ForcedState = .withWins) {
        self.forced = forceState
        self.currentUserID = MockCameraRepository.meID

        switch forceState {
        case .withWins:
            self.wins = MockCameraRepository.fixtureWins
            self.activeWinID = MockCameraRepository.fixtureWins.first?.id
            self.summary = TodayCameraSummary(
                photoCount: 3,
                gridURL: URL(string: "https://images.unsplash.com/photo-1546484959-f9a381d1330d?w=400")
            )
        case .noWins:
            self.wins = []
            self.activeWinID = nil
            self.summary = .empty
        case .maxedOut:
            self.wins = MockCameraRepository.fixtureWins
            self.activeWinID = MockCameraRepository.fixtureWins.first?.id
            self.summary = TodayCameraSummary(
                photoCount: MaxPhotosPerDay,
                gridURL: URL(string: "https://images.unsplash.com/photo-1554415707-6e8cfc93fe23?w=400")
            )
        case .error:
            self.wins = []
            self.activeWinID = nil
            self.summary = .empty
        }
    }

    // MARK: - CameraRepository

    func fetchAllWins() async throws -> [Win] {
        try await Task.sleep(nanoseconds: 180_000_000)
        if forced == .error { throw CameraRepositoryError.network }
        return lock.withLock { wins }
    }

    func fetchActiveWinID() async throws -> UUID? {
        try await Task.sleep(nanoseconds: 90_000_000)
        if forced == .error { throw CameraRepositoryError.network }
        return lock.withLock { activeWinID }
    }

    func setActiveWinID(_ id: UUID?) async throws {
        try await Task.sleep(nanoseconds: 80_000_000)
        if forced == .error { throw CameraRepositoryError.network }
        lock.withLock { activeWinID = id }
    }

    func fetchTodaySummary() async throws -> TodayCameraSummary {
        try await Task.sleep(nanoseconds: 120_000_000)
        if forced == .error { throw CameraRepositoryError.network }
        return lock.withLock { summary }
    }

    func uploadPhoto(
        winID: UUID?,
        imageData: Data,
        capturedAt: Date
    ) async throws -> CapturedPhoto {
        try await Task.sleep(nanoseconds: 600_000_000)
        if forced == .error { throw CameraRepositoryError.network }

        return lock.withLock {
            summary.photoCount = min(summary.photoCount + 1, MaxPhotosPerDay)
            let photo = CapturedPhoto(
                id: UUID(),
                rawURL: URL(string: "https://example.com/raw/\(UUID().uuidString).jpg"),
                updatedGridURL: summary.gridURL,
                updatedMainURL: summary.gridURL,
                newPhotoCount: summary.photoCount
            )
            return photo
        }
    }

    // MARK: - Fixtures

    private static let meID = UUID(uuidString: "00000000-0000-0000-0000-0000000000aa")!

    static let fixtureWins: [Win] = [
        Win(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            name: "Overnight Oats",
            currentStreak: 14
        ),
        Win(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            name: "Matcha Run",
            currentStreak: 5
        ),
        Win(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            name: "Go to gym",
            currentStreak: 0
        ),
        Win(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            name: "Watch Lebron Highlights",
            currentStreak: 14
        ),
    ]
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}
