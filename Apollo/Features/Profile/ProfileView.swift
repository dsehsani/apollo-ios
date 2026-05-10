//
//  ProfileView.swift
//  Apollo
//
//  Profile screen (PRD §06). Supports both the current user's own profile
//  (tab bar entry) and any other user's profile (pushed from feed avatar tap).
//
//  Own profile:
//    • Tap avatar  → PhotosPicker → compress → upload to avatars bucket
//    • Tap banner  → action sheet with three options:
//        1. Choose from camera roll → PhotosPicker (banner)
//        2. Choose from my wins    → BannerPickFromWinsSheet (grid picker)
//        3. Reset to auto          → pulls recent photos from DB
//

import Kingfisher
import PhotosUI
import Supabase
import SwiftUI

private struct ProfilePhotoViewerItem: Identifiable {
    let id = UUID()
    var post: ProfilePost
    var startingIndex: Int
    var username: String
}

struct ProfileView: View {

    @State private var viewModel: ProfileViewModel
    @State private var showBannerEditSheet = false
    @State private var showAvatarPicker = false
    @State private var showBannerCameraRollPicker = false
    @State private var showBannerWinsPicker = false
    @State private var showMemories = false
    @State private var avatarPickerItem: PhotosPickerItem?
    @State private var bannerPickerItem: PhotosPickerItem?
    @State private var photoViewerItem: ProfilePhotoViewerItem?

    private let signedInID: UUID

    // MARK: Init

    /// - Parameters:
    ///   - userID: The profile to display. Pass `nil` (default) for the signed-in user.
    ///   - currentUser: The currently signed-in user — used to determine `isCurrentUser`
    ///     and to build the repository. Falls back to `supabase.auth.currentUser`.
    init(userID: UUID? = nil, currentUser: CurrentUser? = nil) {
        let resolvedSignedInID = currentUser?.id ?? supabase.auth.currentUser?.id ?? UUID()
        let targetID           = userID ?? resolvedSignedInID
        let repo = SupabaseProfileRepository(
            currentUserID: resolvedSignedInID,
            profileUserID: targetID
        )
        signedInID = resolvedSignedInID
        _viewModel = State(initialValue: ProfileViewModel(userID: targetID, repository: repo))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.apolloBackground.ignoresSafeArea()

                ScrollView {
                    switch viewModel.phase {
                    case .loading:
                        skeletonContent
                    case .loaded(let user, let post):
                        loadedContent(user: user, post: post)
                    case .error(let message):
                        errorContent(message: message)
                    }
                }
                .scrollIndicators(.hidden)
                .refreshable { await viewModel.refresh() }

                // Upload-in-progress banners
                if viewModel.uploadingAvatar {
                    uploadOverlay(label: "Updating avatar…")
                }
                if viewModel.uploadingBanner {
                    uploadOverlay(label: "Updating banner…")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showMemories) {
                MemoriesView(
                    userID: signedInID,
                    repository: SupabaseMemoriesRepository(userID: signedInID)
                )
            }
        }
        .task { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .apolloProfileShouldRefresh)) { _ in
            Task { await viewModel.refresh() }
        }
        // Banner edit action sheet
        .sheet(isPresented: $showBannerEditSheet) {
            bannerEditSheet
        }
        // Full-screen photo viewer
        .fullScreenCover(item: $photoViewerItem) { item in
            let bridged = Post(
                id: item.post.id,
                user: PostUser(id: UUID(), username: item.username, avatarURL: nil, streak: 0),
                createdAt: .now,
                caption: item.post.caption,
                photoCount: 1 + item.post.towerPhotos.count,
                mainPhotoURL: item.post.mainPhotoURL,
                towerPhotos: item.post.towerPhotos,
                winsCount: item.post.winsCount,
                reactions: item.post.reactions,
                commentCount: item.post.commentCount,
                currentUserReaction: nil
            )
            FullScreenPhotoViewer(post: bridged, startingIndex: item.startingIndex) {
                photoViewerItem = nil
            }
        }
        // "Choose from my wins" grid picker
        .sheet(isPresented: $showBannerWinsPicker) {
            BannerPickFromWinsSheet(viewModel: viewModel) {
                showBannerWinsPicker = false
            }
        }
        // Avatar photo picker
        .photosPicker(
            isPresented: $showAvatarPicker,
            selection: $avatarPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: avatarPickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await viewModel.changeAvatar(image: image)
                }
                avatarPickerItem = nil
            }
        }
        // Banner camera-roll photo picker
        .photosPicker(
            isPresented: $showBannerCameraRollPicker,
            selection: $bannerPickerItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: bannerPickerItem) { _, item in
            // #region agent log
            DebugFileLog.log("H2", "ProfileView.bannerPickerItem.onChange", "picker selection changed", [
                "hasItem": item != nil,
            ])
            // #endregion
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    // #region agent log
                    DebugFileLog.log("H3", "ProfileView.bannerPickerItem.loaded", "loaded image data", [
                        "byteCount": data.count,
                        "imageSize": "\(image.size.width)x\(image.size.height)",
                    ])
                    // #endregion
                    await viewModel.applyBannerFromCameraRoll(image: image)
                } else {
                    // #region agent log
                    DebugFileLog.log("H3", "ProfileView.bannerPickerItem.loadFailed", "failed to load Data/UIImage from picker item", [:])
                    // #endregion
                }
                bannerPickerItem = nil
            }
        }
        // Transient error toast
        .overlay(alignment: .top) {
            if let msg = viewModel.transientError {
                Text(msg)
                    .font(.sfPro(14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.85))
                    .clipShape(Capsule())
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { viewModel.clearTransientError() }
                    .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.transientError)
    }

    // MARK: - Inline hero bar

    private func heroBar(isCurrentUser: Bool) -> some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Profile")
                .font(.goudyRegular(36))
                .foregroundStyle(Color.apolloPrimaryText)

            Spacer()

            HStack(spacing: 24) {
                circleIconButton(systemName: "calendar", action: { showMemories = true })
                if isCurrentUser {
                    circleIconButton(systemName: "bell", action: {})
                } else {
                    Menu {
                        Button("Add friend", action: {})
                        Button("Remove friend", action: {})
                        Button(role: .destructive) {} label: { Text("Report") }
                    } label: {
                        circleIconLabel(systemName: "ellipsis")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    private func circleIconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            circleIconLabel(systemName: systemName)
        }
        .buttonStyle(.plain)
    }

    private func circleIconLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(Color.apolloPrimaryText)
            .frame(width: 40, height: 40)
            .background(Color.apolloSkeleton)
            .clipShape(Circle())
    }

    // MARK: - Loaded state

    @ViewBuilder
    private func loadedContent(user: ProfileUser, post: ProfilePost?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBar(isCurrentUser: user.isCurrentUser)

            ProfileBannerView(
                photoURLs: user.bannerPhotoURLs,
                isCurrentUser: user.isCurrentUser,
                onTap: { showBannerEditSheet = true }
            )

            avatarHeaderView(user: user)
                .padding(.top, 16)

            if let post {
                TodaysWinsSection(
                    post: post,
                    isCurrentUser: user.isCurrentUser,
                    featuredPhotoIndex: viewModel.featuredPhotoIndex,
                    onFeaturedPhotoTap: {
                        photoViewerItem = ProfilePhotoViewerItem(
                            post: post, startingIndex: 0, username: user.handle
                        )
                    },
                    onTowerPhotoTap: { idx in
                        photoViewerItem = ProfilePhotoViewerItem(
                            post: post, startingIndex: idx + 1, username: user.handle
                        )
                    },
                    onMoreTap: {},
                    onReactionsLineTap: {},
                    onCommentTap: {}
                )
                .padding(.top, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    emptyWinsHeader
                    TodaysWinsEmptyView(onCameraTap: {})
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 48)
        }
    }

    /// ProfileHeaderView with an edit overlay on the avatar for the current user.
    @ViewBuilder
    private func avatarHeaderView(user: ProfileUser) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                AvatarCircleView(url: user.avatarURL, size: 80)
                    .overlay(Circle().stroke(Color.apolloBackground, lineWidth: 2))

                if user.isCurrentUser {
                    Button {
                        showAvatarPicker = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.apolloText)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.apolloBackground, lineWidth: 1.5))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.sfPro(24, weight: .regular))
                        .foregroundStyle(Color.apolloPrimaryText)
                        .lineLimit(1)
                    Text("@\(user.handle)")
                        .font(.sfPro(16))
                        .foregroundStyle(Color.apolloWinsLabel)
                        .lineLimit(1)
                }

                HStack(spacing: 22) {
                    statItem(value: "\(user.totalWins)",  label: "Wins")
                    statItem(value: "\(user.streak)d",    label: "Streak")
                    statItem(value: "\(user.friendCount)", label: "Friends")
                }
                .padding(.vertical, 10)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    private func statItem(value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.sfPro(16, weight: .semibold))
                .foregroundStyle(Color.apolloCaption)
            Text(label)
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloWinsLabel)
        }
    }

    private var emptyWinsHeader: some View {
        Text("TODAY'S WINS")
            .font(.sfPro(15))
            .foregroundStyle(Color.apolloTimeStreak)
            .padding(.horizontal, 16)
            .padding(.top, 24)
    }

    // MARK: - Skeleton state

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroBar(isCurrentUser: true)
            ProfileBannerSkeletonView()
            ProfileHeaderSkeletonView()
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.apolloSkeleton)
                    .frame(width: 100, height: 10)
                    .padding(.horizontal, 16)
                    .padding(.top, 24)

                Color.apolloSkeleton
                    .frame(maxWidth: .infinity)
                    .frame(height: 303)
            }
        }
    }

    // MARK: - Error state

    private func errorContent(message: String) -> some View {
        VStack(spacing: 20) {
            heroBar(isCurrentUser: true)
            Spacer()
            Text(message)
                .font(.sfPro(15))
                .foregroundStyle(Color.apolloCaption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") {
                Task { await viewModel.load() }
            }
            .font(.sfPro(15, weight: .semibold))
            .foregroundStyle(Color.apolloText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 500)
    }

    // MARK: - Upload overlay

    private func uploadOverlay(label: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.8)
            Text(label)
                .font(.sfPro(13))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .clipShape(Capsule())
        .padding(.top, 60)
        .zIndex(30)
        .transition(.opacity)
    }

    // MARK: - Banner edit sheet

    private var bannerEditSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.apolloStroke)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            VStack(spacing: 0) {
                sheetOption("Choose from camera roll") {
                    // #region agent log
                    DebugFileLog.log("H2", "ProfileView.sheetOption.cameraRoll", "tapped 'Choose from camera roll'", [:])
                    // #endregion
                    showBannerEditSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        // #region agent log
                        DebugFileLog.log("H2", "ProfileView.sheetOption.cameraRoll.delayed", "setting showBannerCameraRollPicker = true after 350ms", [:])
                        // #endregion
                        showBannerCameraRollPicker = true
                    }
                }
                Divider().background(Color.apolloBorder)
                sheetOption("Choose from my wins") {
                    showBannerEditSheet = false
                    Task { await viewModel.loadOwnRecentWinPhotos() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showBannerWinsPicker = true
                    }
                }
                Divider().background(Color.apolloBorder)
                sheetOption("Reset to auto") {
                    showBannerEditSheet = false
                    Task { await viewModel.resetBannerToAuto() }
                }
            }
            .background(Color.apolloSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.apolloBackground.ignoresSafeArea())
        .presentationDetents([.height(240)])
        .presentationDragIndicator(.hidden)
    }

    private func sheetOption(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.sfPro(16))
                .foregroundStyle(Color.apolloText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AvatarCircleView

/// Reusable async-loading circle avatar (used here + tab bar).
struct AvatarCircleView: View {
    var url: URL?
    var size: CGFloat

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

// MARK: - BannerPickFromWinsSheet

/// A full-screen style sheet showing a 3-column grid of the user's own win
/// photos. User selects up to 12; tapping "Use Selected" calls
/// `viewModel.applyBannerFromWins(urls:)`.
struct BannerPickFromWinsSheet: View {
    @Bindable var viewModel: ProfileViewModel
    let onDismiss: () -> Void

    @State private var selectedURLs: Set<URL> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.apolloBackground.ignoresSafeArea()

                if viewModel.ownRecentWinPhotos.isEmpty {
                    Text("No win photos yet.")
                        .font(.sfPro(15))
                        .foregroundStyle(Color.apolloCaption)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(viewModel.ownRecentWinPhotos, id: \.self) { url in
                                photoCell(url: url)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose from Wins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                        .foregroundStyle(Color.apolloText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Selected") {
                        Task {
                            await viewModel.applyBannerFromWins(urls: Array(selectedURLs))
                            onDismiss()
                        }
                    }
                    .foregroundStyle(Color.apolloText)
                    .disabled(selectedURLs.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private func photoCell(url: URL) -> some View {
        let isSelected = selectedURLs.contains(url)
        Button {
            if isSelected {
                selectedURLs.remove(url)
            } else if selectedURLs.count < 12 {
                selectedURLs.insert(url)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                KFImage(url)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
                    .overlay(isSelected ? Color.black.opacity(0.35) : Color.clear)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ProfileView()
        .preferredColorScheme(.dark)
}
