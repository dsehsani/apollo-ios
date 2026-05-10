//
//  WinDetailsViewModel.swift
//  Apollo
//
//  View model for the Win Details bottom sheet (PRD §05).
//  Handles both create mode (new win from input field) and edit mode (existing win).
//

import Foundation
import SwiftUI

@Observable
final class WinDetailsViewModel: Identifiable {

    let id = UUID()

    // MARK: - Mode

    enum Mode {
        case create
        case edit
    }

    // MARK: - Editable state

    var name: String
    var size: WinSize
    var repeatSchedule: WinRepeat
    var repeatDays: [Int]
    var remindMe: Bool
    var reminderTime: Date

    // MARK: - UI state

    var nameShakeOffset: CGFloat = 0
    var showDeleteAlert: Bool = false
    var isSaving: Bool = false
    var isMarkingDone: Bool = false
    var isDeleting: Bool = false
    var errorMessage: String?

    // MARK: - Identity

    let mode: Mode
    /// The original win in edit mode; nil in create mode.
    let originalWin: WinListItem?

    // MARK: - Callbacks

    var onSave: ((WinListItem) -> Void)?
    var onDelete: (() -> Void)?
    var onMarkDone: ((WinListItem) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Private

    private let repository: WinListRepository

    // MARK: - Init

    /// Create mode — pre-fills the name from what was typed.
    init(createWithName name: String, repository: WinListRepository) {
        self.mode = .create
        self.originalWin = nil
        self.name = name
        self.size = .m
        self.repeatSchedule = .daily
        self.repeatDays = []
        self.remindMe = false
        self.reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
        self.repository = repository
    }

    /// Edit mode — pre-populates all fields from the existing win.
    init(editing win: WinListItem, repository: WinListRepository) {
        self.mode = .edit
        self.originalWin = win
        self.name = win.name
        self.size = win.size
        self.repeatSchedule = win.repeatSchedule
        self.repeatDays = win.repeatDays
        self.remindMe = win.remindMe
        self.reminderTime = win.reminderTime
            ?? Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())
            ?? Date()
        self.repository = repository
    }

    // MARK: - Computed

    var showMarkAsDone: Bool {
        guard mode == .edit, let win = originalWin else { return false }
        return !win.completedToday
    }

    // MARK: - Save

    @MainActor
    func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            shakeName()
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            let saved: WinListItem
            switch mode {
            case .create:
                saved = try await repository.createWin(
                    name: trimmed,
                    size: size,
                    repeatSchedule: repeatSchedule,
                    repeatDays: repeatDays
                )
            case .edit:
                guard var updated = originalWin else { return }
                updated.name = trimmed
                updated.size = size
                updated.repeatSchedule = repeatSchedule
                updated.repeatDays = repeatDays
                updated.remindMe = remindMe
                updated.reminderTime = remindMe ? reminderTime : nil
                saved = try await repository.updateWin(updated)
            }

            if remindMe {
                await scheduleWinReminder(for: saved)
            } else if mode == .edit, let win = originalWin {
                NotificationsService.shared.cancelWinReminder(winID: win.id)
            }

            isSaving = false
            onSave?(saved)
            onDismiss?()
        } catch {
            isSaving = false
            errorMessage = "Couldn't save. Try again."
        }
    }

    // MARK: - Mark as done

    @MainActor
    func markDone() async {
        guard let win = originalWin else { return }
        isMarkingDone = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        do {
            let updated = try await repository.toggleComplete(win.id, date: .now)
            isMarkingDone = false
            onMarkDone?(updated)
            onDismiss?()
        } catch {
            isMarkingDone = false
            errorMessage = "Couldn't save. Try again."
        }
    }

    // MARK: - Delete

    @MainActor
    func delete() async {
        guard let win = originalWin else { return }
        isDeleting = true
        do {
            try await repository.deleteWin(win.id)
            NotificationsService.shared.cancelWinReminder(winID: win.id)
            isDeleting = false
            onDelete?()
            onDismiss?()
        } catch {
            isDeleting = false
            errorMessage = "Couldn't delete. Try again."
        }
    }

    // MARK: - Shake animation

    private func shakeName() {
        let offsets: [CGFloat] = [8, -8, 6, -6, 4, -4, 0]
        var delay: Double = 0
        for offset in offsets {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                withAnimation(.easeInOut(duration: 0.04)) {
                    self?.nameShakeOffset = offset
                }
            }
            delay += 0.04
        }
    }

    // MARK: - Local notifications (delegated to NotificationsService)

    @MainActor
    private func scheduleWinReminder(for win: WinListItem) async {
        let repeatMode: WinReminderRepeat
        switch win.repeatSchedule {
        case .daily:            repeatMode = .daily
        case .weekly:           repeatMode = .weekly
        case .once, .custom:    repeatMode = .once
        }

        let service = NotificationsService.shared
        if service.authorizationStatus == .notDetermined {
            _ = await service.requestAuthorization(context: .settings)
        }
        service.scheduleWinReminder(
            winID: win.id,
            name: win.name,
            time: reminderTime,
            repeat: repeatMode
        )
    }

}
