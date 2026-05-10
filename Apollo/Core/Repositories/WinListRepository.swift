//
//  WinListRepository.swift
//  Apollo
//
//  Repository protocol for Win List data (PRD §04 §7–8).
//

import Foundation

protocol WinListRepository: Sendable {
    /// Returns wins for the given tab. Today returns only today's scheduled wins;
    /// allWins returns every win grouped active → completed today → inactive.
    func fetchWins(tab: WinTab) async throws -> [WinListItem]

    /// Creates a new win with the given properties.
    func createWin(name: String, size: WinSize, repeatSchedule: WinRepeat, repeatDays: [Int]) async throws -> WinListItem

    /// Updates all mutable fields of an existing win.
    func updateWin(_ win: WinListItem) async throws -> WinListItem

    /// Toggles completion status for a win on the given date.
    func toggleComplete(_ winID: UUID, date: Date) async throws -> WinListItem

    /// Soft-deletes a win.
    func deleteWin(_ winID: UUID) async throws

    /// Persists a new sort order for the supplied ordered array of IDs.
    func reorderWins(_ orderedIDs: [UUID]) async throws
}
