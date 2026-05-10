//
//  NewPostsBanner.swift
//  Apollo
//

import SwiftUI

struct NewPostsBanner: View {
    var count: Int
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(count == 1 ? "1 new post" : "\(count) new posts")
                .font(.sfPro(13, weight: .medium))
                .foregroundStyle(Color.apolloText)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.apolloSurface, in: Capsule())
                .overlay(
                    Capsule().stroke(Color.apolloBorder, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

#Preview {
    NewPostsBanner(count: 1, onTap: {})
        .padding()
        .background(Color.apolloBackground)
}
