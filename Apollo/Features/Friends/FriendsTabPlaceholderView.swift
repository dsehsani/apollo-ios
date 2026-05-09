//
//  FriendsTabPlaceholderView.swift
//  Apollo
//
//  Tab destination placeholder. Future agents will replace with the real Friends screen.
//

import SwiftUI

struct FriendsTabPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()
            Text("Friends")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
        }
    }
}

#Preview {
    FriendsTabPlaceholderView()
        .preferredColorScheme(.dark)
}
