//
//  MaxedOutLabel.swift
//  Apollo
//
//  Shown below the disabled shutter once the user has captured
//  `MaxPhotosPerDay` (default 6) photos today. PRD §9 and §14.
//

import SwiftUI

struct MaxedOutLabel: View {
    var body: some View {
        Text("You've maxed out today's wins. 🏆")
            .font(.sfPro(13))
            .foregroundStyle(Color.apolloIconStroke)
            .multilineTextAlignment(.center)
            .accessibilityLabel("You've maxed out today's wins.")
    }
}

#Preview {
    MaxedOutLabel()
        .padding()
        .background(Color.apolloBackground)
}
