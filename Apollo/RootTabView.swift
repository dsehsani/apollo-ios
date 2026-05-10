//
//  RootTabView.swift
//  Apollo
//
//  Top-level shell: a native SwiftUI TabView with five tabs. The tab bar uses
//  the standard system material on iOS 17; iOS 26+ upgrades it to Liquid Glass.
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

import Supabase
import SwiftUI

struct RootTabView: View {
    enum TabSelection: Hashable {
        case feed, friends, camera, north, profile
    }

    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationsService: NotificationsService
    @ObservedObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selection: TabSelection = .feed
    @State private var showCamera: Bool = false
    @State private var showPushPrompt: Bool = false

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
            FeedView(currentUser: sessionStore.currentUser)
                .tag(TabSelection.feed)
                .tabItem { Label("Feed", systemImage: "house") }

            FriendsView(currentUser: sessionStore.currentUser)
                .tag(TabSelection.friends)
                .tabItem { Label("Friends", systemImage: "person.2") }

            // Never displayed - selectionBinding intercepts before content renders.
            Color.clear
                .tag(TabSelection.camera)
                .tabItem { Label("Camera", systemImage: "camera") }

            NorthTabPlaceholderView()
                .tag(TabSelection.north)
                .tabItem { Label("North", systemImage: "asterisk") }

            ProfileView(currentUser: sessionStore.currentUser)
                .tag(TabSelection.profile)
                .tabItem {
                    Label {
                        Text("Profile")
                    } icon: {
                        if let avatar = sessionStore.currentUserAvatarImage {
                            Image(uiImage: avatar)
                                .renderingMode(.original)
                        } else {
                            Image("ProfileTabAvatarPlaceholder")
                                .renderingMode(.original)
                        }
                    }
                }
        }
        .onAppear {
            // #region agent log
            DebugFileLog.log("H1", "RootTabView.onAppear", "TabView appeared", [
                "hasAvatarURL": sessionStore.currentUser?.avatarURL != nil,
                "avatarURL": sessionStore.currentUser?.avatarURL?.absoluteString ?? "<nil>",
            ])
            // #endregion
        }
        // Deep link routing from push taps.
        .onChange(of: deepLinkRouter.targetTab) { _, newTab in
            guard let newTab else { return }
            switch newTab {
            case .feed:     selection = .feed
            case .friends:  selection = .friends
            case .north:    selection = .north
            case .profile:  selection = .profile
            }
            deepLinkRouter.targetTab = nil
        }
        // Post-first-win push permission prompt.
        .onChange(of: notificationsService.shouldShowPermissionPrompt) { _, show in
            if show { showPushPrompt = true }
        }
        .sheet(isPresented: $showPushPrompt, onDismiss: {
            notificationsService.shouldShowPermissionPrompt = false
        }) {
            EnableNotificationsPromptView {
                showPushPrompt = false
                notificationsService.shouldShowPermissionPrompt = false
            }
            .environmentObject(notificationsService)
            .presentationDetents([.fraction(0.55)])
            .presentationDragIndicator(.hidden)
        }
        .fullScreenCover(isPresented: $showCamera) {
            let userID = sessionStore.currentUser?.id ?? supabase.auth.currentUser?.id ?? UUID()
            CameraView(
                repository: SupabaseCameraRepository(currentUserID: userID),
                postRepository: SupabasePostRepository(currentUserID: userID),
                winListRepository: SupabaseWinListRepository(currentUserID: userID),
                onClose: { showCamera = false }
            )
        }
    }
}

#Preview {
    RootTabView()
        .preferredColorScheme(.dark)
}
