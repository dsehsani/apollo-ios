//
//  CameraPlaceholderView.swift
//  Apollo
//
//  Placeholder for the Camera screen — opened from the empty-state Win button.
//

import SwiftUI

struct CameraPlaceholderView: View {
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()
            VStack {
                Spacer()
                Text("Camera Screen")
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
