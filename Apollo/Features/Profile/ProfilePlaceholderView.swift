//
//  ProfilePlaceholderView.swift
//  Apollo
//
//  Placeholder pushed from Feed (avatar/username tap).
//

import SwiftUI

struct ProfilePlaceholderView: View {
    var user: PostUser

    var body: some View {
        VStack {
            Spacer()
            Text("Profile Screen")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
            Text("@\(user.username)")
                .font(.sfPro(14))
                .foregroundStyle(Color.apolloMuted)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.apolloBackground)
    }
}
