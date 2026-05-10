//
//  FeedSkeleton.swift
//  Apollo
//

import SwiftUI

struct FeedSkeleton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var visible = false

    var body: some View {
        VStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonPostBlock()
            }
            Spacer(minLength: 0)
        }
        .opacity(visible ? (pulse ? 0.7 : 0.4) : 0.0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) { visible = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

private struct SkeletonPostBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.apolloSkeleton)
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 6) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.apolloSkeleton)
                        .frame(width: 120, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.apolloSkeleton)
                        .frame(width: 90, height: 10)
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            Rectangle()
                .fill(Color.apolloSkeleton)
                .frame(height: 320)

            RoundedRectangle(cornerRadius: 4)
                .fill(Color.apolloSkeleton)
                .frame(width: 240, height: 14)
                .padding(.horizontal, 16)
        }
    }
}

#Preview {
    FeedSkeleton()
        .background(Color.apolloBackground)
}
