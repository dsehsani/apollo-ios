//
//  WinListModels.swift
//  Apollo
//
//  Data models for the Win List screen (PRD §04).
//

import Foundation

// MARK: - WinSize

enum WinSize: String, CaseIterable, Identifiable, Codable, Sendable {
    case s = "S"
    case m = "M"
    case l = "L"

    var id: String { rawValue }

    var next: WinSize {
        switch self {
        case .s: return .m
        case .m: return .l
        case .l: return .s
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .s: return "Small"
        case .m: return "Medium"
        case .l: return "Large"
        }
    }
}

// MARK: - WinRepeat

enum WinRepeat: String, CaseIterable, Codable, Sendable {
    case once
    case daily
    case weekly
    case custom

    var displayName: String {
        switch self {
        case .once:   return "Just once"
        case .daily:  return "Every day"
        case .weekly: return "Once a week"
        case .custom: return "Pick days"
        }
    }
}

// MARK: - WinListItem

struct WinListItem: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var size: WinSize
    var repeatSchedule: WinRepeat
    var currentStreak: Int
    var completedToday: Bool
    var sortOrder: Int
    var isActive: Bool
    var repeatDays: [Int]
    var remindMe: Bool
    var reminderTime: Date?

    init(
        id: UUID = UUID(),
        name: String,
        size: WinSize = .m,
        repeatSchedule: WinRepeat = .daily,
        currentStreak: Int = 0,
        completedToday: Bool = false,
        sortOrder: Int = 0,
        isActive: Bool = true,
        repeatDays: [Int] = [],
        remindMe: Bool = false,
        reminderTime: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.size = size
        self.repeatSchedule = repeatSchedule
        self.currentStreak = currentStreak
        self.completedToday = completedToday
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.repeatDays = repeatDays
        self.remindMe = remindMe
        self.reminderTime = reminderTime
    }
}

// MARK: - WinTab

enum WinTab: String, CaseIterable, Hashable, Sendable {
    case today = "Today"
    case allWins = "All Wins"

    var title: String { rawValue }
}

// MARK: - WinListPhase

enum WinListPhase: Equatable, Sendable {
    case loading
    case loaded
    case empty
    case error
}
