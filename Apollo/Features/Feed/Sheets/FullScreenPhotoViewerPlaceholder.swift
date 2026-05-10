//
//  FullScreenPhotoViewerPlaceholder.swift
//  Apollo
//
//  Placeholder for the full-screen photo viewer modal.
//

import SwiftUI

struct FullScreenPhotoViewerPlaceholder: View {
    var post: Post
    var startingIndex: Int
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()
            VStack {
                Spacer()
                Text("Full Screen Photo Viewer")
                    .font(.goudyItalic(20))
                    .foregroundStyle(Color.apolloText)
                Spacer()
                Button("Close", action: onClose)
                    .foregroundStyle(Color.apolloText)
                    .padding()
            }
        }
    }
}
