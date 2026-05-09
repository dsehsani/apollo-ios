//
//  ShareStripPlaceholder.swift
//  Apollo
//
//  Placeholder for the Share Strip Screen — pushed in the navigation stack.
//

import SwiftUI

struct ShareStripPlaceholder: View {
    var post: Post

    var body: some View {
        VStack {
            Spacer()
            Text("Share Strip Screen")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
        .navigationBarBackButtonHidden(false)
    }
}
