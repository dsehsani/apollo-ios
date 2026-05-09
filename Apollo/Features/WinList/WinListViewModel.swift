//
//  WinListViewModel.swift
//  Apollo
//
//  View model for the Win List screen (PRD §04).
//  Uses @Observable and async/await. Applies optimistic UI for toggle and create.
//

import Foundation
import SwiftUI
import UIKit

@Observable
final class WinListViewModel {

    // MARK: - Published state

    var wins: [WinListItem] = []
    var tab: WinTab = .today
    var phase: WinListPhase = .loading
    var inputText: String = ""
    var inputSize: WinSize = .m
    var transientErrorMessage: String?
    /// Non-nil when the details sheet should open in create mode with this pre-filled name.
    var pendingCreateName: String?

    // MARK: - Private

    private let repository: WinListRepository

    init(repository: WinListRepository = MockWinListRepository()) {
        self.repository = repository
    }

    // MARK: - Lifecycle

    func onAppear() {
        Task { await load() }
    }

    // MARK: - Data loading

    func load() async {
        phase = .loading
        do {
            let fetched = try await repository.fetchWins(tab: tab)
            wins = fetched
            phase = fetched.isEmpty ? .empty : .loaded
        } catch {
            phase = .error
            transientErrorMessage = "Couldn't load your wins."
        }
    }

    func switchTab(_ newTab: WinTab) {
        guard newTab != tab else { return }
        tab = newTab
        Task { await load() }
    }

    // MARK: - Win creation

    /// Opens the Details sheet in create mode with the typed name pre-filled.
    func submitInput() {
        let name = inputText.trimmingCharacters(in: .whitespaces)
        guard name.count >= 1 else { return }
        inputText = ""
        inputSize = .m
        pendingCreateName = name
    }

    /// Called by WinDetailsViewModel.onSave when a new win is saved from the sheet.
    func addWin(_ win: WinListItem) {
        wins.append(win)
        if phase == .empty || phase == .loading { phase = .loaded }
    }

    // MARK: - Completion toggle

    func toggleComplete(_ win: WinListItem) {
        guard let idx = wins.firstIndex(of: win) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let wasCompleted = wins[idx].completedToday
        wins[idx].completedToday = !wasCompleted
        wins[idx].currentStreak = wasCompleted
            ? max(0, wins[idx].currentStreak - 1)
            : wins[idx].currentStreak + 1

        reorderAfterToggle()

        let winID = win.id
        Task {
            do {
                let updated = try await repository.toggleComplete(winID, date: .now)
                if let i = wins.firstIndex(where: { $0.id == winID }) {
                    wins[i] = updated
                }
            } catch {
                if let i = wins.firstIndex(where: { $0.id == winID }) {
                    wins[i].completedToday = wasCompleted
                    wins[i].currentStreak = wasCompleted
                        ? wins[i].currentStreak + 1
                        : max(0, wins[i].currentStreak - 1)
                    reorderAfterToggle()
                }
                showTransientError("Couldn't update. Try again.")
            }
        }
    }

    // MARK: - Win update (from details sheet)

    /// Applies an already-persisted update to the local wins array (no repo call).
    func applyWinUpdate(_ win: WinListItem) {
        guard let idx = wins.firstIndex(where: { $0.id == win.id }) else { return }
        wins[idx] = win
        reorderAfterToggle()
    }

    /// Removes a win from the local list (repo call already made by caller).
    func removeWin(_ winID: UUID) {
        wins.removeAll { $0.id == winID }
        if wins.isEmpty { phase = .empty }
    }

    // MARK: - Details VM factory

    func makeCreateVM(name: String) -> WinDetailsViewModel {
        WinDetailsViewModel(createWithName: name, repository: repository)
    }

    func makeEditVM(win: WinListItem) -> WinDetailsViewModel {
        WinDetailsViewModel(editing: win, repository: repository)
    }

    // MARK: - Deletion

    func deleteWin(_ win: WinListItem) {
        wins.removeAll { $0.id == win.id }
        if wins.isEmpty { phase = .empty }

        Task {
            do {
                try await repository.deleteWin(win.id)
            } catch {
                wins.append(win)
                if phase == .empty { phase = .loaded }
                showTransientError("Couldn't delete your win. Try again.")
            }
        }
    }

    // MARK: - Reorder

    func reorder(from source: IndexSet, to destination: Int) {
        wins.move(fromOffsets: source, toOffset: destination)
        let orderedIDs = wins.map(\.id)
        Task {
            try? await repository.reorderWins(orderedIDs)
        }
    }

    // MARK: - Error

    func clearTransientError() {
        transientErrorMessage = nil
    }

    // MARK: - Private helpers

    private func reorderAfterToggle() {
        let incomplete = wins.filter { !$0.completedToday }
        let complete   = wins.filter { $0.completedToday }
        wins = incomplete + complete
    }

    private func showTransientError(_ message: String) {
        transientErrorMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if transientErrorMessage == message {
                transientErrorMessage = nil
            }
        }
    }
}
