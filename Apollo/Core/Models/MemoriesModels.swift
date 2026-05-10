//
//  MemoriesModels.swift
//  Apollo
//
//  Data models for the Memories / Calendar screen (PRD §11).
//

import Foundation

struct MemoryDay: Identifiable, Hashable, Sendable {
    /// Post UUID when there's a post, otherwise a synthesised UUID keyed by the UTC date.
    let id: UUID
    /// UTC calendar date at 00:00:00.
    var date: Date
    /// Nil when no post was made on this day.
    var postID: UUID?
    var mainPhotoURL: URL?
    /// Ordered tower photos (positions 1+), used alongside mainPhotoURL in FullScreenPhotoViewer.
    var towerPhotoURLs: [URL]
    var reactionCount: Int
    var winCount: Int
    var caption: String

    var hasPost: Bool { postID != nil }
}

struct MemoryMonth: Hashable, Sendable {
    var year: Int
    var month: Int            // 1...12
    /// Sparse map: day-of-month → MemoryDay. Only days with posts are stored; empty days
    /// are inferred at render time from the calendar so months with zero posts still display.
    var days: [Int: MemoryDay]
}

extension MemoryMonth: Identifiable {
    var id: String { "\(year)-\(month)" }
}
