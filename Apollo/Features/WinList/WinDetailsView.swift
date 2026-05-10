//
//  WinDetailsView.swift
//  Apollo
//
//  Win Details bottom sheet (PRD §05).
//
//  Presentation: .large detent, hidden drag indicator, apolloBackground sheet background.
//
//  Structure:
//    ZStack (apolloBackground)
//      VStack
//        SheetHeader (drag pill + nav row)
//        ScrollView
//          WinNameField
//          SizeSelectorSection
//          RepeatPickerSection (+ DaySelectorRow if "Pick days")
//          RemindMeSection (+ DatePicker if on)
//          MarkAsDoneButton (edit mode, not completed today)
//          DeleteWinButton (edit mode)
//      ErrorToast (overlay)
//

import SwiftUI

struct WinDetailsView: View {
    @State private var viewModel: WinDetailsViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: WinDetailsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.apolloBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                sheetHeader
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        nameField
                        sizeSection
                        repeatSection
                        remindMeSection

                        if viewModel.showMarkAsDone {
                            markAsDoneButton
                        }

                        if viewModel.mode == .edit {
                            deleteButton
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 48)
                }
                .scrollDismissesKeyboard(.immediately)
            }

            if let message = viewModel.errorMessage {
                ErrorToast(
                    message: message,
                    actionLabel: nil,
                    onAction: nil,
                    onDismiss: { viewModel.errorMessage = nil }
                )
                .padding(.top, 4)
                .zIndex(10)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.apolloBackground)
        .confirmationDialog(
            deleteDialogTitle,
            isPresented: $viewModel.showDeleteAlert,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your streak will be lost.")
        }
    }

    // MARK: - Sheet header

    private var sheetHeader: some View {
        VStack(spacing: 12) {
            // Drag pill
            Capsule()
                .fill(Color.apolloWinDetailsDragPill)
                .frame(width: 32, height: 4)
                .padding(.top, 10)

            // Nav row
            ZStack {
                Text("Details")
                    .font(.sfPro(14))
                    .foregroundStyle(Color(red: 0x66/255, green: 0x66/255, blue: 0x66/255))

                HStack {
                    // X button
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.apolloWinDetailsXButton)
                                .frame(width: 28, height: 28)
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(Color.apolloIconStroke)
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")

                    Spacer()

                    // Checkmark / save button
                    Button {
                        Task { await viewModel.save() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.apolloPrimaryText)
                                .frame(width: 28, height: 28)
                            if viewModel.isSaving {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(Color.apolloBackground)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.apolloBackground)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSaving)
                    .accessibilityLabel("Save")
                }
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Win name field

    private var nameField: some View {
        TextField("Name your win", text: $viewModel.name)
            .font(.sfPro(22, weight: .medium))
            .foregroundStyle(Color.apolloPrimaryText)
            .tint(Color.apolloPrimaryText)
            .submitLabel(.done)
            .onChange(of: viewModel.name) { _, new in
                if new.count > 60 {
                    viewModel.name = String(new.prefix(60))
                }
            }
            .offset(x: viewModel.nameShakeOffset)
            .padding(.horizontal, 20)
            .accessibilityLabel("Win name")
    }

    // MARK: - Size selector

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIZE")
                .font(.sfPro(10))
                .foregroundStyle(Color.apolloMuted)
                .tracking(0.8)

            HStack(spacing: 8) {
                ForEach(WinSize.allCases) { size in
                    sizePill(size)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func sizePill(_ size: WinSize) -> some View {
        let isSelected = viewModel.size == size
        return Button {
            withAnimation(.easeInOut(duration: 0.12)) {
                viewModel.size = size
            }
        } label: {
            Text(size.rawValue)
                .font(.sfPro(13, weight: .medium))
                .foregroundStyle(isSelected ? Color.apolloBackground : Color.apolloWinDetailsPillText)
                .frame(width: 64, height: 36)
                .background(isSelected ? Color.apolloPrimaryText : Color.apolloSkeleton)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.apolloWinDetailsPillBorder, lineWidth: 0.5)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Size \(size.accessibilityLabel)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Repeat picker

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("REPEAT")
                .font(.sfPro(10))
                .foregroundStyle(Color.apolloMuted)
                .tracking(0.8)
                .padding(.bottom, 4)

            ForEach(WinRepeat.allCases, id: \.self) { option in
                repeatRow(option)
            }

            if viewModel.repeatSchedule == .custom {
                daySelectorRow
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: viewModel.repeatSchedule)
    }

    private func repeatRow(_ option: WinRepeat) -> some View {
        let isSelected = viewModel.repeatSchedule == option
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.repeatSchedule = option
            }
        } label: {
            HStack {
                Text(option.displayName)
                    .font(.sfPro(15))
                    .foregroundStyle(isSelected ? Color.apolloPrimaryText : Color.apolloWinDetailsRepeatMuted)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.apolloPrimaryText)
                }
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.displayName). \(isSelected ? "Selected" : "Not selected").")
    }

    // MARK: - Day selector row

    private static let weekdayLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var daySelectorRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { index in
                let dayIndex = index + 1 // 1=Sun … 7=Sat
                let isOn = viewModel.repeatDays.contains(dayIndex)
                Button {
                    withAnimation(.easeInOut(duration: 0.12)) {
                        if isOn {
                            viewModel.repeatDays.removeAll { $0 == dayIndex }
                        } else {
                            viewModel.repeatDays.append(dayIndex)
                            viewModel.repeatDays.sort()
                        }
                    }
                } label: {
                    Text(Self.weekdayLabels[index])
                        .font(.sfPro(12, weight: .medium))
                        .foregroundStyle(isOn ? Color.apolloBackground : Color.apolloWinDetailsPillText)
                        .frame(width: 32, height: 32)
                        .background(isOn ? Color.apolloPrimaryText : Color.apolloSkeleton)
                        .clipShape(Circle())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"][index]). \(isOn ? "Selected" : "Not selected").")
            }
        }
    }

    // MARK: - Remind me

    private var remindMeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Remind me")
                    .font(.sfPro(15))
                    .foregroundStyle(Color.apolloWinDetailsRepeatMuted)
                Spacer()
                Toggle("", isOn: $viewModel.remindMe)
                    .labelsHidden()
                    .tint(Color.apolloPrimaryText)
            }
            .frame(height: 48)

            if viewModel.remindMe {
                DatePicker(
                    "",
                    selection: $viewModel.reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: viewModel.remindMe)
    }

    // MARK: - Mark as done

    private var markAsDoneButton: some View {
        Button {
            Task { await viewModel.markDone() }
        } label: {
            HStack {
                Spacer()
                if viewModel.isMarkingDone {
                    ProgressView()
                        .tint(Color.apolloPrimaryText)
                } else {
                    Text("Mark as done")
                        .font(.sfPro(15))
                        .foregroundStyle(Color.apolloPrimaryText)
                }
                Spacer()
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isMarkingDone)
        .accessibilityLabel("Mark as done")
    }

    // MARK: - Delete win

    private var deleteButton: some View {
        Button {
            viewModel.showDeleteAlert = true
        } label: {
            HStack {
                Spacer()
                Text("Delete win")
                    .font(.sfPro(15))
                    .foregroundStyle(Color.apolloWinDetailsDeleteText)
                Spacer()
            }
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
        .accessibilityLabel("Delete win. Destructive action.")
    }

    private var deleteDialogTitle: String {
        let winName = viewModel.originalWin?.name ?? viewModel.name
        return "Delete \(winName)?"
    }
}

// MARK: - Previews

#Preview("Create mode") {
    let vm = WinDetailsViewModel(
        createWithName: "Morning run",
        repository: MockWinListRepository()
    )
    return WinDetailsView(viewModel: vm)
}

#Preview("Edit mode") {
    let win = WinListItem(
        name: "Deep work block",
        size: .l,
        repeatSchedule: .daily,
        currentStreak: 3,
        completedToday: false
    )
    let vm = WinDetailsViewModel(editing: win, repository: MockWinListRepository())
    return WinDetailsView(viewModel: vm)
}

#Preview("Edit — completed today") {
    let win = WinListItem(
        name: "Meditate",
        size: .s,
        repeatSchedule: .daily,
        currentStreak: 21,
        completedToday: true
    )
    let vm = WinDetailsViewModel(editing: win, repository: MockWinListRepository())
    return WinDetailsView(viewModel: vm)
}

#Preview("Pick days") {
    let win = WinListItem(
        name: "Weekly review",
        size: .m,
        repeatSchedule: .custom,
        repeatDays: [2, 6]
    )
    let vm = WinDetailsViewModel(editing: win, repository: MockWinListRepository())
    return WinDetailsView(viewModel: vm)
}
