//
//  FriendAvatarView.swift
//  Apollo
//
//  44pt circle avatar used across all Friends rows.
//  Kingfisher-ready: swaps the skeleton circle for a real KFImage when url != nil.
//

import SwiftUI
import Kingfisher

struct FriendAvatarView: View {
    var url: URL?
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let url {
                KFImage(url)
                    .resizable()
                    .placeholder { Circle().fill(Color.apolloSkeleton) }
                    .scaledToFill()
            } else {
                Circle().fill(Color.apolloSkeleton)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
