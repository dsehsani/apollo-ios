//
//  WinRowView.swift
//  Apollo
//
//  Individual win row — PRD §4B + Figma visual language.
//
//  Layout (left → right):
//    16pt | ○ circle (22×22) | 12pt | name + streak | Spacer | size badge | 12pt | chevron | 16pt
//
//  Height: 56pt. No hairline dividers — spacing only.
//

import SwiftUI

struct WinRowView: View {
    let win: WinListItem
    let onToggleComplete: () -> Void
    let onDetailsTap: () -> Void
    /// When provided (e.g. camera context), tapping the circle/name calls this
    /// instead of toggle/details. The chevron always opens details.
    var onSelect: (() -> Void)? = nil
    /// Drives a temporary filled-circle animation before the sheet dismisses.
    var showAsSelected: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            completionCircle
                .padding(.leading, 16)
                .onTapGesture(perform: onSelect ?? onToggleComplete)
                .accessibilityLabel("\(win.name), \(win.completedToday ? "complete" : "incomplete")")
                .accessibilityHint(onSelect != nil ? "Double tap to select." : "Double tap to toggle.")
                .accessibilityAddTraits(.isButton)

            nameAndStreak
                .padding(.leading, 12)
                .onTapGesture(perform: onSelect ?? onDetailsTap)

            Spacer(minLength: 8)

            sizeBadge
                .padding(.trailing, 12)

            detailsButton
                .padding(.trailing, 16)
        }
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    // MARK: - Completion circle

    private var completionCircle: some View {
        let filled = win.completedToday || showAsSelected
        return ZStack {
            if filled {
                Circle()
                    .fill(Color.apolloText)
                    .frame(width: 22, height: 22)
            } else {
                Circle()
                    .stroke(Color.apolloStroke, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .frame(width: 44, height: 44)
        .animation(.easeInOut(duration: 0.18), value: filled)
    }

    // MARK: - Name + streak

    private var nameAndStreak: some View {
        HStack(spacing: 8) {
            Text(win.name)
                .font(.sfPro(15, weight: .medium))
                .foregroundStyle(win.completedToday ? Color.apolloMuted : Color.apolloText)
                .lineLimit(1)
                .animation(.easeInOut(duration: 0.18), value: win.completedToday)

            if win.currentStreak > 0 {
                Text("\(win.currentStreak)d 🔥")
                    .font(.sfPro(12))
                    .foregroundStyle(Color.apolloMuted)
            }
        }
    }

    // MARK: - Size badge

    private var sizeBadge: some View {
        Text(win.size.rawValue)
            .font(.goudyItalic(11))
            .foregroundStyle(Color.apolloPrimaryText)
    }

    // MARK: - Details / chevron button

    private var detailsButton: some View {
        Button(action: onDetailsTap) {
            Image(systemName: "chevron.up")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Color.apolloMuted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit \(win.name)")
    }
}

#Preview {
    VStack(spacing: 0) {
        WinRowView(
            win: WinListItem(name: "Morning run", size: .m, currentStreak: 14),
            onToggleComplete: {},
            onDetailsTap: {}
        )
        WinRowView(
            win: WinListItem(name: "Deep work block", size: .l, currentStreak: 3, completedToday: true),
            onToggleComplete: {},
            onDetailsTap: {}
        )
        WinRowView(
            win: WinListItem(name: "Cold shower", size: .s),
            onToggleComplete: {},
            onDetailsTap: {}
        )
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
