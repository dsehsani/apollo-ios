//
//  ProfileTabPlaceholderView.swift
//  Apollo
//
//  Tab destination placeholder for the user's own profile. Distinct from
//  ProfilePlaceholderView(user:), which is pushed from a feed avatar tap and
//  shows whichever PostUser was tapped. Future agents will replace this with
//  the real Profile screen sourcing the current user from Supabase.
//

import SwiftUI

struct ProfileTabPlaceholderView: View {
    var body: some View {
        ZStack {
            Color.apolloBackground.ignoresSafeArea()
            Text("Profile")
                .font(.goudyItalic(20))
                .foregroundStyle(Color.apolloText)
        }
    }
}

#Preview {
    ProfileTabPlaceholderView()
        .preferredColorScheme(.dark)
}
