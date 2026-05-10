//
//  FriendsSectionHeader.swift
//  Apollo
//
//  Uppercase 10pt section label. Matches PRD §4D.
//

import SwiftUI

struct FriendsSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.sfPro(10))
            .foregroundStyle(Color.apolloTimeStreak)
            .tracking(1)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

#Preview {
    VStack(alignment: .leading) {
        FriendsSectionHeader(title: "Requests")
        FriendsSectionHeader(title: "Recommended")
    }
    .background(Color.apolloBackground)
    .preferredColorScheme(.dark)
}
