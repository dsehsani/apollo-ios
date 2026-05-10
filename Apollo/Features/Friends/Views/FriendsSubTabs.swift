//
//  FriendsSubTabs.swift
//  Apollo
//
//  Friends / Challenges tab selector. Matches Figma node 12892:4835.
//  Challenges tab is non-functional for v1.
//

import SwiftUI

enum FriendsTab {
    case friends, challenges
}

struct FriendsSubTabs: View {
    @Binding var selected: FriendsTab

    var body: some View {
        HStack(spacing: 36) {
            tabLabel("Friends", tab: .friends)
            tabLabel("Challenges", tab: .challenges)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func tabLabel(_ title: String, tab: FriendsTab) -> some View {
        Button {
            selected = tab
        } label: {
            Text(title)
                .font(.goudyRegular(20))
                .foregroundStyle(selected == tab ? Color.apolloPrimaryText : Color.apolloTabInactive)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var tab: FriendsTab = .friends
    FriendsSubTabs(selected: $tab)
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
