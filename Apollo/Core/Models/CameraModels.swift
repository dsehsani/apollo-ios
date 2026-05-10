//
//  CameraModels.swift
//  Apollo
//
//  Shared data models for the Camera screen. Shapes mirror the Camera PRD §7
//  (Active win, all wins, today's grid thumbnail, photo count) and §8 (POST
//  /photos/capture response).
//

import Foundation

struct Win: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var currentStreak: Int
}

struct TodayCameraSummary: Hashable, Sendable {
    var photoCount: Int
    var gridURL: URL?

    nonisolated static let empty = TodayCameraSummary(photoCount: 0, gridURL: nil)
}

struct CapturedPhoto: Hashable, Sendable {
    let id: UUID
    var rawURL: URL?
    var updatedGridURL: URL?
    var updatedMainURL: URL?
    var newPhotoCount: Int
}

enum CameraRepositoryError: Error, Sendable {
    case network
    case rateLimited
    case forbidden
    case unknown
}

enum CameraFlashMode: String, CaseIterable, Hashable, Sendable {
    case off
    case on
    case auto

    var next: CameraFlashMode {
        switch self {
        case .off: return .on
        case .on: return .auto
        case .auto: return .off
        }
    }

    var voiceOverLabel: String {
        switch self {
        case .off: return "Flash off"
        case .on: return "Flash on"
        case .auto: return "Flash auto"
        }
    }
}

enum CameraPosition: String, Hashable, Sendable {
    case back
    case front

    var toggled: CameraPosition { self == .back ? .front : .back }
}
