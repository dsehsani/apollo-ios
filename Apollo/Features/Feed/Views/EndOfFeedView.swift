//
//  EndOfFeedView.swift
//  Apollo
//

import SwiftUI

struct EndOfFeedView: View {
    var quote: Quote?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("You're all caught up.")
                .font(.goudyItalic(18))
                .foregroundStyle(Color.apolloText)
            if let quote {
                Text(quote.text)
                    .font(.goudyItalic(14))
                    .foregroundStyle(Color.apolloQuote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 100)
    }
}

#Preview {
    EndOfFeedView(quote: Quote(text: "Small wins, every day, become a life.", date: .now))
        .background(Color.apolloBackground)
}
