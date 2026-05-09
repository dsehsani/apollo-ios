//
//  CommentsSheetPlaceholder.swift
//  Apollo
//
//  Placeholder until the real Comments Sheet is built in a separate session.
//  Routed via FeedView .sheet(item:).
//

import SwiftUI

struct CommentsSheetPlaceholder: View {
    var post: Post

    var body: some View {
        VStack {
            Spacer()
            Text("Comments Sheet")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
        .presentationDetents([.medium, .large])
    }
}
