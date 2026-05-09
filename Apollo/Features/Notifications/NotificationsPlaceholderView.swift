//
//  NotificationsPlaceholderView.swift
//  Apollo
//
//  Placeholder pushed from the Feed bell icon.
//

import SwiftUI

struct NotificationsPlaceholderView: View {
    var body: some View {
        VStack {
            Spacer()
            Text("Notifications Screen")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
    }
}
