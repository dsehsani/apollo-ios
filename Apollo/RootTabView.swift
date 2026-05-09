//
//  RootTabView.swift
//  Apollo
//
//  Top-level shell: a native SwiftUI TabView with five tabs. iOS 26 applies
//  liquid glass to the tab bar automatically.
//
//  Tabs: Feed, Friends, Camera, North, Profile.
//
//  The Camera tab is intercepted: tapping it does not change the selected
//  tab; instead it presents `CameraPlaceholderView` via fullScreenCover so
//  the camera surface always behaves as a modal capture flow regardless of
//  where the user came from.
//
//  The Profile tab uses `Image("ProfileTabAvatarPlaceholder")` (Original
//  rendering) so the icon is a real raster image rather than a tinted
//  template. When the real avatar is wired up from Supabase, swap that
//  Image for a KFImage(currentUser.avatarURL) clipped to a Circle.
//

import SwiftUI

struct RootTabView: View {
    enum TabSelection: Hashable {
        case feed, friends, camera, north, profile
    }

    @State private var selection: TabSelection = .feed
    @State private var showCamera: Bool = false

    private var selectionBinding: Binding<TabSelection> {
        Binding(
            get: { selection },
            set: { newValue in
                if newValue == .camera {
                    showCamera = true
                } else {
                    selection = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: selectionBinding) {
            FeedView()
                .tag(TabSelection.feed)
                .tabItem { Label("Feed", systemImage: "house") }

            FriendsTabPlaceholderView()
                .tag(TabSelection.friends)
                .tabItem { Label("Friends", systemImage: "person.2") }

            // Never displayed - selectionBinding intercepts before content renders.
            Color.clear
                .tag(TabSelection.camera)
                .tabItem { Label("Camera", systemImage: "camera") }

            NorthTabPlaceholderView()
                .tag(TabSelection.north)
                .tabItem { Label("North", systemImage: "asterisk") }

            ProfileTabPlaceholderView()
                .tag(TabSelection.profile)
                .tabItem {
                    Label {
                        Text("Profile")
                    } icon: {
                        Image("ProfileTabAvatarPlaceholder")
                            .renderingMode(.original)
                    }
                }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(onClose: { showCamera = false })
        }
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
