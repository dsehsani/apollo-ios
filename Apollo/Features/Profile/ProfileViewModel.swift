//
//  ProfileViewModel.swift
//  Apollo
//
//  @Observable view model for ProfileView (PRD §06).
//

import Foundation
import Observation
import Supabase
import UIKit

@Observable
final class ProfileViewModel {

    enum Phase {
        case loading
        case loaded(ProfileUser, ProfilePost?)
        case error(String)
    }

    private(set) var phase: Phase = .loading
    var featuredPhotoIndex: Int = 0

    var uploadingAvatar: Bool = false
    var uploadingBanner: Bool = false
    var transientError: String?

    /// Recent win-photo URLs loaded for the "Choose from my wins" banner picker.
    private(set) var ownRecentWinPhotos: [URL] = []

    private let userID: UUID
    private let repository: any ProfileRepositoryProtocol

    init(userID: UUID, repository: any ProfileRepositoryProtocol) {
        self.userID = userID
        self.repository = repository
    }

    // MARK: - Load / refresh

    func load() async {
        phase = .loading
        do {
            let (user, post) = try await repository.fetchProfile(userID: userID)
            phase = .loaded(user, post)
        } catch {
            phase = .error("Couldn't load profile. Try again.")
        }
    }

    func refresh() async {
        do {
            let (user, post) = try await repository.fetchProfile(userID: userID)
            phase = .loaded(user, post)
        } catch {
            phase = .error("Couldn't load profile. Try again.")
        }
    }

    func setFeaturedPhoto(_ index: Int) {
        featuredPhotoIndex = index
    }

    // MARK: - Avatar upload

    /// Compress to ≤ 512 px, upload to `avatars` bucket, update users row.
    func changeAvatar(image: UIImage) async {
        uploadingAvatar = true
        transientError = nil
        defer { uploadingAvatar = false }

        guard let data = resized(image, maxDimension: 512).jpegData(compressionQuality: 0.85) else {
            transientError = "Couldn't process image."
            return
        }

        do {
            let url = try await repository.uploadAvatar(data)
            if case .loaded(var user, let post) = phase {
                user.avatarURL = url
                phase = .loaded(user, post)
            }
            NotificationCenter.default.post(name: .apolloProfileShouldRefresh, object: nil)
        } catch {
            transientError = "Avatar upload failed."
        }
    }

    // MARK: - Banner: camera roll

    func applyBannerFromCameraRoll(image: UIImage) async {
        // #region agent log
        DebugFileLog.log("H3", "ProfileViewModel.applyBannerFromCameraRoll", "entry", [
            "inputSize": "\(image.size.width)x\(image.size.height)",
        ])
        // #endregion
        uploadingBanner = true
        transientError = nil
        defer { uploadingBanner = false }

        guard let data = resized(image, maxDimension: 1200).jpegData(compressionQuality: 0.82) else {
            // #region agent log
            DebugFileLog.log("H3", "ProfileViewModel.applyBannerFromCameraRoll", "jpeg compression failed", [:])
            // #endregion
            transientError = "Couldn't process image."
            return
        }

        do {
            // #region agent log
            DebugFileLog.log("H3", "ProfileViewModel.applyBannerFromCameraRoll", "before uploadBannerPhoto", [
                "byteCount": data.count,
            ])
            // #endregion
            let url = try await repository.uploadBannerPhoto(data)
            // #region agent log
            DebugFileLog.log("H3", "ProfileViewModel.applyBannerFromCameraRoll", "uploadBannerPhoto OK", [
                "url": url.absoluteString,
            ])
            // #endregion
            try await repository.setBannerPhotos([url], type: "custom")
            // #region agent log
            DebugFileLog.log("H4", "ProfileViewModel.applyBannerFromCameraRoll", "setBannerPhotos OK", [:])
            // #endregion
            if case .loaded(var user, let post) = phase {
                user.bannerPhotoURLs = [url]
                phase = .loaded(user, post)
                // #region agent log
                DebugFileLog.log("H5", "ProfileViewModel.applyBannerFromCameraRoll", "optimistic phase update applied", [
                    "newBannerCount": user.bannerPhotoURLs.count,
                ])
                // #endregion
            } else {
                // #region agent log
                DebugFileLog.log("H5", "ProfileViewModel.applyBannerFromCameraRoll", "phase NOT .loaded — skipping optimistic update", [:])
                // #endregion
            }
        } catch {
            let ns = error as NSError
            // #region agent log
            DebugFileLog.log("H3", "ProfileViewModel.applyBannerFromCameraRoll", "FAILED", [
                "errDomain": ns.domain,
                "errCode": ns.code,
                "errDesc": ns.localizedDescription,
                "errType": String(describing: type(of: error)),
            ])
            // #endregion
            transientError = "Banner upload failed."
        }
    }

    // MARK: - Banner: choose from wins

    func applyBannerFromWins(urls: [URL]) async {
        uploadingBanner = true
        transientError = nil
        defer { uploadingBanner = false }

        do {
            try await repository.setBannerPhotos(urls, type: "custom")
            if case .loaded(var user, let post) = phase {
                user.bannerPhotoURLs = urls
                phase = .loaded(user, post)
            }
        } catch {
            transientError = "Couldn't save banner selection."
        }
    }

    // MARK: - Banner: reset to auto

    func resetBannerToAuto() async {
        uploadingBanner = true
        transientError = nil
        defer { uploadingBanner = false }

        do {
            try await repository.setBannerPhotos([], type: "auto")
            let autoPhotos = (try? await repository.fetchOwnRecentWinPhotos(limit: 12)) ?? []
            if case .loaded(var user, let post) = phase {
                user.bannerPhotoURLs = autoPhotos
                phase = .loaded(user, post)
            }
        } catch {
            transientError = "Couldn't reset banner."
        }
    }

    // MARK: - Load recent photos for win picker

    func loadOwnRecentWinPhotos() async {
        do {
            ownRecentWinPhotos = try await repository.fetchOwnRecentWinPhotos(limit: 36)
        } catch {
            ownRecentWinPhotos = []
        }
    }

    // MARK: - Error dismissal

    func clearTransientError() {
        transientError = nil
    }

    // MARK: - Private helpers

    private func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
