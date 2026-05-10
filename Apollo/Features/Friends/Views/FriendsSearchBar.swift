//
//  FriendsSearchBar.swift
//  Apollo
//
//  Pill-shaped search field. Matches Figma node 12839:2984.
//

import SwiftUI

struct FriendsSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.apolloWinsValue)

            TextField("", text: $text, prompt:
                Text("Add or search friends")
                    .foregroundStyle(Color.apolloWinsValue)
                    .font(.sfPro(16))
            )
            .font(.sfPro(16))
            .foregroundStyle(Color.apolloPrimaryText)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16)
        .frame(height: 43)
        .background(Color.apolloFriendsPillFill)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(Color.apolloTabInactive, lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    @Previewable @State var text = ""
    FriendsSearchBar(text: $text)
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
