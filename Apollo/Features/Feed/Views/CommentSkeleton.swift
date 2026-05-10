//
//  CommentSkeleton.swift
//  Apollo
//
//  Skeleton placeholder rows shown while comments are loading (PRD §3E).
//  Six rows of #141414 shimmer lines.
//

import SwiftUI

struct CommentSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6) { i in
                CommentSkeletonRow(isReply: i % 3 == 2)
            }
        }
    }
}

private struct CommentSkeletonRow: View {
    var isReply: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Avatar placeholder
            Circle()
                .fill(Color.apolloSkeleton)
                .frame(width: isReply ? 18 : 22, height: isReply ? 18 : 22)

            VStack(alignment: .leading, spacing: 6) {
                // Username + timestamp line
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.apolloSkeleton)
                        .frame(width: CGFloat.random(in: 48...80), height: 8)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.apolloSkeleton)
                        .frame(width: 20, height: 8)
                }
                // Comment text line(s)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.apolloSkeleton)
                    .frame(width: CGFloat.random(in: 120...220), height: 10)
                if i % 2 == 0 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.apolloSkeleton)
                        .frame(width: CGFloat.random(in: 80...160), height: 10)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .padding(.leading, isReply ? 28 : 0)
    }

    // Stable random widths per row index
    private var i: Int { isReply ? 1 : 0 }
}

#Preview {
    CommentSkeleton()
        .background(Color.apolloBackground)
        .preferredColorScheme(.dark)
}
