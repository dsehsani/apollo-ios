//
//  FeedTabRow.swift
//  Apollo
//

import SwiftUI

struct FeedTabRow: View {
    var selected: FeedTab
    var onSelect: (FeedTab) -> Void

    var body: some View {
        HStack(spacing: 36) {
            ForEach(FeedTab.allCases, id: \.self) { tab in
                Button {
                    onSelect(tab)
                } label: {
                    Text(tab.title)
                        .font(.goudyRegular(20))
                        .tracking(-0.4)
                        .foregroundStyle(tab == selected ? Color.apolloPrimaryText : Color.apolloTabInactive)
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

    private func accessibilityLabel(for tab: FeedTab) -> String {
        switch tab {
        case .now:
            return tab == selected ? "Today's posts, selected" : "Today's posts"
        case .yesterday:
            return "Yesterday's posts"
        }
    }
}

#Preview {
    FeedTabRow(selected: .now, onSelect: { _ in })
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
