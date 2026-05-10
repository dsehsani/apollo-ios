//
//  SupabaseProfileRepository.swift
//  Apollo
//
//  Supabase-backed ProfileRepository. Reads the `profile_users` view (which
//  joins users + user_banners), fetches today's post + photos, and handles
//  avatar/banner uploads.
//
//  Upload paths:
//    avatars/{uid}/{uuid}.jpg   (bucket: avatars)
//    banners/{uid}/{uuid}.jpg   (bucket: banners)
//

import Foundation
import Supabase
import UIKit

final class SupabaseProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {

    let currentUserID: UUID   // signed-in user
    let profileUserID: UUID   // profile being viewed (may differ)

    init(currentUserID: UUID, profileUserID: UUID) {
        self.currentUserID = currentUserID
        self.profileUserID = profileUserID
    }

    // MARK: - Fetch profile

    func fetchProfile(userID: UUID) async throws -> (ProfileUser, ProfilePost?) {
        // 1. profile_users view row
        let userRow: ProfileUserRow = try await supabase
            .from("profile_users")
            .select()
            .eq("id", value: userID)
            .single()
            .execute()
            .value

        // 2. Today's post (UTC date)
        let todayUTC = utcDateString(from: Date())
        let postRows: [ProfilePostRow] = (try? await supabase
            .from("posts")
            .select()
            .eq("user_id", value: userID)
            .eq("post_date", value: todayUTC)
            .is("deleted_at", value: Bool?.none)
            .limit(1)
            .execute()
            .value) ?? []

        let profilePost: ProfilePost?
        if let postRow = postRows.first {
            // 3. Photos for that post, ordered by position
            let photos: [PhotoRow] = (try? await supabase
                .from("photos")
                .select()
                .eq("post_id", value: postRow.id)
                .order("position", ascending: true)
                .execute()
                .value) ?? []

            // 4. First 5 reactions
            let reactions: [ReactionJoinRow] = (try? await supabase
                .from("reactions")
                .select("id, post_id, user_id, emoji, created_at, users(username, avatar_url)")
                .eq("post_id", value: postRow.id)
                .order("created_at", ascending: false)
                .limit(5)
                .execute()
                .value) ?? []

            let mainURL = photos.first.flatMap { URL(string: $0.raw_url) }
            let towerSlots: [PhotoSlot] = photos.dropFirst().enumerated().map { idx, p in
                PhotoSlot(id: p.id, url: URL(string: p.raw_url), index: idx + 1)
            }

            profilePost = ProfilePost(
                id: postRow.id,
                winsCount: postRow.win_count,
                mainPhotoURL: mainURL,
                towerPhotos: towerSlots,
                caption: postRow.caption ?? "",
                reactions: reactions.map(mapReaction),
                commentCount: 0
            )
        } else {
            profilePost = nil
        }

        // 5. Banner: use stored URLs, or fall back to recent photos for "auto" type
        var bannerURLs = userRow.banner_photo_urls.compactMap(URL.init(string:))
        // #region agent log
        DebugFileLog.log("H5", "SupabaseProfileRepository.fetchProfile", "banner row read", [
            "stored_urls_count": userRow.banner_photo_urls.count,
            "banner_type": userRow.banner_type,
        ])
        // #endregion
        if bannerURLs.isEmpty {
            bannerURLs = (try? await fetchRecentWinPhotoURLs(userID: userID, limit: 12)) ?? []
            // #region agent log
            DebugFileLog.log("H5", "SupabaseProfileRepository.fetchProfile", "banner empty -> auto fallback", [
                "auto_count": bannerURLs.count,
            ])
            // #endregion
        }

        let user = ProfileUser(
            id: userRow.id,
            displayName: userRow.display_name ?? userRow.username,
            handle: userRow.handle ?? userRow.username,
            avatarURL: userRow.avatar_url.flatMap(URL.init(string:)),
            bannerPhotoURLs: bannerURLs,
            totalWins: userRow.total_wins,
            streak: userRow.current_streak,
            friendCount: userRow.friend_count,
            isCurrentUser: userID == currentUserID
        )

        return (user, profilePost)
    }

    // MARK: - Avatar upload

    func uploadAvatar(_ data: Data) async throws -> URL {
        let path = "\(currentUserID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        do {
            try await supabase.storage
                .from("avatars")
                .upload(path: path, file: data,
                        options: FileOptions(contentType: "image/jpeg", upsert: false))
        } catch {
            throw ProfileRepositoryError.uploadFailed(reason: error.localizedDescription)
        }

        let url: URL
        do {
            url = try supabase.storage.from("avatars").getPublicURL(path: path)
        } catch {
            try? await supabase.storage.from("avatars").remove(paths: [path])
            throw ProfileRepositoryError.uploadFailed(reason: error.localizedDescription)
        }

        struct AvatarUpdate: Encodable { let avatar_url: String }
        try await supabase
            .from("users")
            .update(AvatarUpdate(avatar_url: url.absoluteString))
            .eq("id", value: currentUserID)
            .execute()

        return url
    }

    // MARK: - Banner photo upload

    func uploadBannerPhoto(_ data: Data) async throws -> URL {
        let path = "\(currentUserID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"

        // #region agent log
        let authUID = supabase.auth.currentUser?.id
        DebugFileLog.log("H4", "SupabaseProfileRepository.uploadBannerPhoto", "before storage upload", [
            "path": path,
            "byteCount": data.count,
            "currentUserID": currentUserID.uuidString.lowercased(),
            "authUID": authUID?.uuidString.lowercased() ?? "<nil>",
            "match": authUID == currentUserID,
        ])
        // #endregion

        do {
            try await supabase.storage
                .from("banners")
                .upload(path: path, file: data,
                        options: FileOptions(contentType: "image/jpeg", upsert: false))
            // #region agent log
            DebugFileLog.log("H4", "SupabaseProfileRepository.uploadBannerPhoto", "storage upload OK", [
                "path": path,
            ])
            // #endregion
        } catch {
            let ns = error as NSError
            // #region agent log
            DebugFileLog.log("H4", "SupabaseProfileRepository.uploadBannerPhoto", "storage upload FAILED", [
                "path": path,
                "errDomain": ns.domain,
                "errCode": ns.code,
                "errDesc": ns.localizedDescription,
                "errUserInfo": String(describing: ns.userInfo),
            ])
            // #endregion
            throw ProfileRepositoryError.uploadFailed(reason: error.localizedDescription)
        }

        do {
            let url = try supabase.storage.from("banners").getPublicURL(path: path)
            // #region agent log
            DebugFileLog.log("H4", "SupabaseProfileRepository.uploadBannerPhoto", "publicURL OK", [
                "url": url.absoluteString,
            ])
            // #endregion
            return url
        } catch {
            try? await supabase.storage.from("banners").remove(paths: [path])
            throw ProfileRepositoryError.uploadFailed(reason: error.localizedDescription)
        }
    }

    // MARK: - Set banner photos

    func setBannerPhotos(_ urls: [URL], type: String) async throws {
        struct BannerUpsert: Encodable {
            let user_id: String
            let photo_urls: [String]
            let type: String
        }
        let payload = BannerUpsert(
            user_id: currentUserID.uuidString.lowercased(),
            photo_urls: urls.map(\.absoluteString),
            type: type
        )
        // #region agent log
        DebugFileLog.log("H4", "SupabaseProfileRepository.setBannerPhotos", "before upsert", [
            "user_id": payload.user_id,
            "type": type,
            "urlCount": urls.count,
        ])
        // #endregion
        do {
            try await supabase
                .from("user_banners")
                .upsert(payload, onConflict: "user_id")
                .execute()
            // #region agent log
            DebugFileLog.log("H4", "SupabaseProfileRepository.setBannerPhotos", "upsert OK", [:])
            // #endregion
        } catch {
            let ns = error as NSError
            // #region agent log
            DebugFileLog.log("H4", "SupabaseProfileRepository.setBannerPhotos", "upsert FAILED", [
                "errDomain": ns.domain,
                "errCode": ns.code,
                "errDesc": ns.localizedDescription,
            ])
            // #endregion
            throw error
        }
    }

    // MARK: - Recent win photos (for picker + auto-banner)

    func fetchOwnRecentWinPhotos(limit: Int) async throws -> [URL] {
        try await fetchRecentWinPhotoURLs(userID: currentUserID, limit: limit)
    }

    // MARK: - Private helpers

    private func fetchRecentWinPhotoURLs(userID: UUID, limit: Int) async throws -> [URL] {
        let rows: [PhotoRawRow] = (try? await supabase
            .from("photos")
            .select("raw_url")
            .eq("user_id", value: userID)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value) ?? []
        return rows.compactMap { URL(string: $0.raw_url) }
    }

    private func utcDateString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = TimeZone(identifier: "UTC")!
        return fmt.string(from: date)
    }

    private func mapReaction(_ r: ReactionJoinRow) -> Reaction {
        Reaction(
            id: r.id,
            postID: r.post_id,
            userID: r.user_id,
            username: r.users?.username ?? "user",
            avatarURL: r.users?.avatar_url.flatMap(URL.init(string:)),
            emoji: r.emoji,
            createdAt: parseTimestamp(r.created_at) ?? Date()
        )
    }

    private func parseTimestamp(_ raw: String) -> Date? {
        let n = raw.replacingOccurrences(of: " ", with: "T")
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = full.date(from: n) { return d }
        let sec = ISO8601DateFormatter()
        sec.formatOptions = [.withInternetDateTime]
        return sec.date(from: n)
    }
}

// MARK: - Decodable row types

private struct ProfileUserRow: Decodable {
    let id: UUID
    let username: String
    let display_name: String?
    let handle: String?
    let avatar_url: String?
    let total_wins: Int
    let current_streak: Int
    let friend_count: Int
    let banner_photo_urls: [String]
    let banner_type: String

    enum CodingKeys: String, CodingKey {
        case id, username, display_name, handle, avatar_url
        case total_wins, current_streak, friend_count
        case banner_photo_urls, banner_type
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self, forKey: .id)
        username       = try c.decode(String.self, forKey: .username)
        display_name   = try c.decodeIfPresent(String.self, forKey: .display_name)
        handle         = try c.decodeIfPresent(String.self, forKey: .handle)
        avatar_url     = try c.decodeIfPresent(String.self, forKey: .avatar_url)
        total_wins     = try c.decode(Int.self, forKey: .total_wins)
        current_streak = try c.decode(Int.self, forKey: .current_streak)
        friend_count   = try c.decode(Int.self, forKey: .friend_count)
        banner_type    = try c.decode(String.self, forKey: .banner_type)

        // banner_photo_urls is a Postgres TEXT[] which may arrive as a JSON array or null
        if let arr = try? c.decode([String].self, forKey: .banner_photo_urls) {
            banner_photo_urls = arr
        } else {
            banner_photo_urls = []
        }
    }
}

private struct ProfilePostRow: Decodable {
    let id: UUID
    let win_count: Int
    let caption: String?
    let photo_count: Int
}

private struct PhotoRow: Decodable {
    let id: UUID
    let raw_url: String
    let position: Int
}

private struct PhotoRawRow: Decodable {
    let raw_url: String
}

private struct ReactionUserEmbed: Decodable {
    let username: String
    let avatar_url: String?
}

private struct ReactionJoinRow: Decodable {
    let id: UUID
    let post_id: UUID
    let user_id: UUID
    let emoji: String
    let created_at: String
    let users: ReactionUserEmbed?

    enum CodingKeys: String, CodingKey {
        case id, post_id, user_id, emoji, created_at, users
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        post_id    = try c.decode(UUID.self, forKey: .post_id)
        user_id    = try c.decode(UUID.self, forKey: .user_id)
        emoji      = try c.decode(String.self, forKey: .emoji)
        created_at = try c.decode(String.self, forKey: .created_at)
        if let embed = try? c.decode(ReactionUserEmbed.self, forKey: .users) {
            users = embed
        } else if let arr = try? c.decode([ReactionUserEmbed].self, forKey: .users),
                  let first = arr.first {
            users = first
        } else {
            users = nil
        }
    }
}
