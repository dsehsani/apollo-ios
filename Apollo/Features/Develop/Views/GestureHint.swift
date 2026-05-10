//
//  GestureHint.swift
//  Apollo
//
//  Dimly visible "shake to develop" hint below the polaroid card.
//  Fades out with easeOut(0.25) when `visible` becomes false.
//

import SwiftUI

struct GestureHint: View {
    let visible: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "wave.3.up")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(Color(white: 0.22)) // #393939

            Text("shake to develop")
                .font(.sfPro(13))
                .foregroundStyle(Color(white: 0.145)) // #252525
        }
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: visible)
    }
}
