//
//  ShootingForLabel.swift
//  Apollo
//
//  "Shooting for / [Win Name] [streak]🔥 ^" label rendered below the
//  viewfinder. Falls back to "Add a win ^" in muted Goudy when no win is
//  active. PRD §4C.
//

import SwiftUI

struct ShootingForLabel: View {
    let activeWin: Win?
    let onTapWinName: () -> Void
    let onTapAddAWin: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Shooting for")
                .font(.sfPro(13))
                .foregroundStyle(Color.apolloIconStroke)

            Button(action: handleTap) {
                if let activeWin {
                    HStack(spacing: 6) {
                        Text(activeWin.name)
                            .font(.goudyItalic(22))
                            .foregroundStyle(Color.apolloText)
                        if activeWin.currentStreak > 0 {
                            Text("\(activeWin.currentStreak)🔥")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.apolloText)
                                .padding(.bottom, 2)
                        }
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.apolloErrorToastBody)
                    }
                } else {
                    HStack(spacing: 6) {
                        Text("Add a win")
                            .font(.goudyItalic(22))
                            .foregroundStyle(Color.apolloIconStroke)
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.apolloIconStroke)
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint(accessibilityHint)
        }
    }

    private func handleTap() {
        if activeWin != nil {
            onTapWinName()
        } else {
            onTapAddAWin()
        }
    }

    private var accessibilityLabel: String {
        if let activeWin {
            return "Shooting for \(activeWin.name), \(activeWin.currentStreak) day streak."
        }
        return "Add a win."
    }

    private var accessibilityHint: String {
        activeWin != nil ? "Double tap to change win." : "Double tap to set up a win."
    }
}

#Preview {
    VStack(spacing: 32) {
        ShootingForLabel(
            activeWin: Win(id: UUID(), name: "Overnight Oats", currentStreak: 14),
            onTapWinName: {},
            onTapAddAWin: {}
        )
        ShootingForLabel(
            activeWin: Win(id: UUID(), name: "Matcha Run", currentStreak: 0),
            onTapWinName: {},
            onTapAddAWin: {}
        )
        ShootingForLabel(activeWin: nil, onTapWinName: {}, onTapAddAWin: {})
    }
    .padding()
    .background(Color.apolloBackground)
}
