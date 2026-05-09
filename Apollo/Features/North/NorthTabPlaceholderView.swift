//
//  NorthTabPlaceholderView.swift
//  Apollo
//
//  Tab destination placeholder. Future agents will replace with the real North screen.
//

import SwiftUI

struct NorthTabPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()
            Text("North")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
        }
    }
}

#Preview {
    NorthTabPlaceholderView()
        .preferredColorScheme(.dark)
}
