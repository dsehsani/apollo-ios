//
//  WinPickerSheet.swift
//  Apollo
//
//  Bottom sheet for switching the active win without leaving the camera.
//  PRD §3D — scrollable list of wins, currently selected has a white-dot
//  indicator, tapping a row commits the selection and dismisses.
//

import SwiftUI

struct WinPickerSheet: View {
    let wins: [Win]
    let activeWinID: UUID?
    let onSelect: (Win) -> Void
    let onAddWin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            handle
                .padding(.top, 8)
                .padding(.bottom, 12)

            Text("Shooting for")
                .font(.sfPro(13))
                .foregroundStyle(Color.apolloIconStroke)
                .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(wins) { win in
                        WinRow(
                            win: win,
                            isSelected: win.id == activeWinID,
                            onTap: { onSelect(win) }
                        )
                    }

                    Button(action: onAddWin) {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.apolloIconStroke)
                                .frame(width: 22, height: 22)
                            Text("Add a win")
                                .font(.sfPro(14, weight: .medium))
                                .foregroundStyle(Color.apolloIconStroke)
                            Spacer()
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add a win")
                }
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.apolloSurface.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.apolloSurface)
    }

    private var handle: some View {
        Capsule()
            .fill(Color.apolloStroke)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
    }
}

private struct WinRow: View {
    let win: Win
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Color.apolloStroke, lineWidth: 1)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Color.apolloText)
                            .frame(width: 10, height: 10)
                    }
                }

                Text(win.name)
                    .font(.sfPro(14, weight: .medium))
                    .foregroundStyle(Color.apolloText)

                Spacer()

                if win.currentStreak > 0 {
                    Text("\(win.currentStreak)🔥")
                        .font(.sfPro(12))
                        .foregroundStyle(Color.apolloMuted)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(win.name), \(win.currentStreak) day streak\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "" : "Double tap to select.")
    }
}

#Preview {
    Color.apolloBackground
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            WinPickerSheet(
                wins: MockCameraRepository.fixtureWins,
                activeWinID: MockCameraRepository.fixtureWins.first?.id,
                onSelect: { _ in },
                onAddWin: {}
            )
        }
        .preferredColorScheme(.dark)
}
