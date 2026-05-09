//
//  WinListTabRow.swift
//  Apollo
//
//  Today / All Wins tab row — Goudy Bookletter italic 24pt, 36pt gap, left-aligned.
//  Matches Figma node 12839-5928.
//

import SwiftUI

struct WinListTabRow: View {
    var selected: WinTab
    var onSelect: (WinTab) -> Void

    var body: some View {
        HStack(spacing: 36) {
            ForEach(WinTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.title)
                        .font(.goudyItalic(24))
                        .tracking(-0.48)
                        .foregroundStyle(tab == selected ? Color.apolloPrimaryText : Color.apolloReactor)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(for: tab))
                .accessibilityAddTraits(tab == selected ? [.isSelected] : [])
            }
            Spacer()
        }
        .padding(.leading, 16)
        .padding(.top, 8)
    }

    private func accessibilityLabel(for tab: WinTab) -> String {
        switch tab {
        case .today:    return tab == selected ? "Today's wins, selected" : "Today's wins"
        case .allWins:  return tab == selected ? "All wins, selected" : "All wins"
        }
    }
}

#Preview {
    WinListTabRow(selected: .today, onSelect: { _ in })
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
