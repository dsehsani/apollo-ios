//
//  ReactionsBreakdownSheetPlaceholder.swift
//  Apollo
//
//  Placeholder until the real Reactions Breakdown Sheet is built.
//

import SwiftUI

struct ReactionsBreakdownSheetPlaceholder: View {
    var post: Post

    var body: some View {
        VStack {
            Spacer()
            Text("Reactions Breakdown Sheet")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
        .presentationDetents([.medium])
    }
}
