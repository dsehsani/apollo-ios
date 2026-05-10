//
//  SupabaseFriendsRepository.swift
//  Apollo
//
//  Supabase-backed FriendsRepositoryProtocol implementation.
//  Queries: friendships (pending/accepted), users (search, recommendations, affiliate code).
//

import Foundation
import Supabase

// MARK: - Private Decodable rows

private struct FriendshipRequestRow: Decodable {
    let id: UUID
    let user_id: UUID
    let status: String
    let created_at: String
    let users: RequestUserEmbed?

    struct RequestUserEmbed: Decodable {
        let display_name: String?
        let username: String
        let handle: String?
        let avatar_url: String?
    }
}

private struct RecommendedUserRow: Decodable {
    let id: UUID
    let display_name: String?
    let username: String
    let handle: String?
    let avatar_url: String?
}

private struct FriendIDRow: Decodable {
    let friend_id: UUID
}

private struct AffiliateRow: Decodable {
    let affiliate_code: String?
}

private struct FriendshipStatusRow: Decodable {
    let id: UUID
    let user_id: UUID
    let friend_id: UUID
    let status: String
}

// MARK: - SupabaseFriendsRepository

final class SupabaseFriendsRepository: FriendsRepositoryProtocol, @unchecked Sendable {
    let currentUserID: UUID

    init(currentUserID: UUID) {
        self.currentUserID = currentUserID
    }

    // MARK: - fetchFriendsData

    func fetchFriendsData() async throws -> FriendsData {
        do {
            // Run incoming requests and accepted friend IDs in parallel.
            async let requestsResp = supabase
                .from("friendships")
                .select("id, user_id, status, created_at, users:users!friendships_user_id_fkey(display_name, username, handle, avatar_url)")
                .eq("friend_id", value: currentUserID)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()

            async let acceptedResp = supabase
                .from("friendships")
                .select("friend_id")
                .eq("user_id", value: currentUserID)
                .eq("status", value: "accepted")
                .execute()

            let decoder = JSONDecoder()

            let requestRows = try decoder.decode([FriendshipRequestRow].self, from: try await requestsResp.data)
            let requests = requestRows.map(mapRequest)

            let acceptedRows = (try? decoder.decode([FriendIDRow].self, from: try await acceptedResp.data)) ?? []
            let acceptedFriendIDs = acceptedRows.map(\.friend_id)

            // Hackathon recommendations: users not already friended, ordered by join date, limit 10.
            let recommended = try await fetchRecommendations(excludingIDs: acceptedFriendIDs)

            return FriendsData(requests: requests, recommended: recommended, contacts: [])
        } catch let err as FriendsRepositoryError {
            throw err
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    private func fetchRecommendations(excludingIDs friendIDs: [UUID]) async throws -> [RecommendedUser] {
        // Build exclusion set: current user + all accepted friends.
        var excluded = friendIDs
        excluded.append(currentUserID)

        // Also exclude users with a pending friendship in either direction.
        let pendingResp = try await supabase
            .from("friendships")
            .select("user_id, friend_id")
            .or("user_id.eq.\(currentUserID),friend_id.eq.\(currentUserID)")
            .execute()

        struct PendingRow: Decodable { let user_id: UUID; let friend_id: UUID }
        let pendingRows = (try? JSONDecoder().decode([PendingRow].self, from: pendingResp.data)) ?? []
        for row in pendingRows {
            if !excluded.contains(row.user_id) { excluded.append(row.user_id) }
            if !excluded.contains(row.friend_id) { excluded.append(row.friend_id) }
        }

        // PostgREST `not in` filter using comma-separated UUIDs.
        let excludedCSV = excluded.map { $0.uuidString.lowercased() }.joined(separator: ",")

        // Filters must be applied on PostgrestFilterBuilder BEFORE transform ops
        // (`.order`/`.limit`) which downcast the type to PostgrestTransformBuilder.
        let filterBuilder = supabase
            .from("users")
            .select("id, display_name, username, handle, avatar_url")

        let filtered = excludedCSV.isEmpty
            ? filterBuilder
            : filterBuilder.not("id", operator: .in, value: "(\(excludedCSV))")

        let resp = try await filtered
            .order("created_at", ascending: false)
            .limit(10)
            .execute()
        let rows = try JSONDecoder().decode([RecommendedUserRow].self, from: resp.data)
        return rows.map { row in
            RecommendedUser(
                id: row.id,
                displayName: row.display_name ?? row.username,
                handle: row.handle ?? row.username,
                avatarURL: row.avatar_url.flatMap(URL.init(string:)),
                subLabel: "New on Apollo"
            )
        }
    }

    // MARK: - acceptRequest

    func acceptRequest(id: UUID, requesterUserID: UUID) async throws {
        do {
            // Flip the original pending row to accepted.
            try await supabase
                .from("friendships")
                .update(["status": "accepted"])
                .eq("id", value: id)
                .eq("friend_id", value: currentUserID)
                .execute()

            // Insert the reverse row so feed query works bidirectionally.
            struct Reverse: Encodable {
                let id: UUID
                let user_id: UUID
                let friend_id: UUID
                let status: String
                let created_at: String
            }
            let now = ISO8601DateFormatter().string(from: Date())
            let reverse = Reverse(
                id: UUID(),
                user_id: currentUserID,
                friend_id: requesterUserID,
                status: "accepted",
                created_at: now
            )
            // Use try? so a stale duplicate row (unique constraint hit) doesn't surface as an error
            // to the caller — the friendship is already reflected via the primary row update.
            try? await supabase
                .from("friendships")
                .insert(reverse)
                .execute()
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    // MARK: - declineRequest

    func declineRequest(id: UUID) async throws {
        do {
            try await supabase
                .from("friendships")
                .delete()
                .eq("id", value: id)
                .eq("friend_id", value: currentUserID)
                .execute()
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    // MARK: - sendFriendRequest

    func sendFriendRequest(to userID: UUID) async throws {
        struct NewFriendship: Encodable {
            let id: UUID
            let user_id: UUID
            let friend_id: UUID
            let status: String
            let created_at: String
        }
        let now = ISO8601DateFormatter().string(from: Date())
        let row = NewFriendship(
            id: UUID(),
            user_id: currentUserID,
            friend_id: userID,
            status: "pending",
            created_at: now
        )
        do {
            try await supabase
                .from("friendships")
                .insert(row)
                .execute()
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    // MARK: - dismissRecommendation (local-only for hackathon)

    func dismissRecommendation(id: UUID) async throws {
        // No DB write needed per spec; handled locally in the view model.
    }

    // MARK: - searchUsers

    func searchUsers(query: String) async throws -> [UserSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        do {
            let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
            let resp = try await supabase
                .from("users")
                .select("id, display_name, username, handle, avatar_url")
                .or("username.ilike.%\(q)%,handle.ilike.%\(q)%")
                .neq("id", value: currentUserID)
                .limit(20)
                .execute()

            let decoder = JSONDecoder()
            let rows = try decoder.decode([RecommendedUserRow].self, from: resp.data)
            guard !rows.isEmpty else { return [] }

            // Batch-fetch friendship rows for all result users so we can annotate state.
            let resultIDs = rows.map(\.id)
            let idCSV = resultIDs.map { $0.uuidString.lowercased() }.joined(separator: ",")
            let myID = currentUserID.uuidString.lowercased()

            let fResp = try await supabase
                .from("friendships")
                .select("id, user_id, friend_id, status")
                .or("and(user_id.eq.\(myID),friend_id.in.(\(idCSV))),and(friend_id.eq.\(myID),user_id.in.(\(idCSV)))")
                .execute()

            let friendshipRows = (try? decoder.decode([FriendshipStatusRow].self, from: fResp.data)) ?? []

            // Build a state map keyed by the other user's ID.
            var stateMap: [UUID: FriendshipState] = [:]
            for f in friendshipRows {
                let otherID = f.user_id == currentUserID ? f.friend_id : f.user_id
                let state: FriendshipState
                if f.status == "accepted" {
                    state = .friends
                } else if f.user_id == currentUserID {
                    state = .requestedByMe
                } else {
                    state = .incomingRequest(friendshipID: f.id)
                }
                stateMap[otherID] = state
            }

            return rows.map { row in
                UserSearchResult(
                    id: row.id,
                    displayName: row.display_name ?? row.username,
                    handle: row.handle ?? row.username,
                    avatarURL: row.avatar_url.flatMap(URL.init(string:)),
                    state: stateMap[row.id] ?? .none
                )
            }
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    // MARK: - fetchAffiliateCode

    func fetchAffiliateCode() async throws -> String? {
        do {
            let resp = try await supabase
                .from("users")
                .select("affiliate_code")
                .eq("id", value: currentUserID)
                .single()
                .execute()
            let row = try JSONDecoder().decode(AffiliateRow.self, from: resp.data)
            return row.affiliate_code
        } catch {
            throw FriendsRepositoryError.network
        }
    }

    // MARK: - Helpers

    private func mapRequest(_ r: FriendshipRequestRow) -> FriendRequest {
        let embed = r.users
        return FriendRequest(
            id: r.id,
            requesterUserID: r.user_id,
            displayName: embed?.display_name ?? embed?.username ?? "Unknown",
            handle: embed?.handle ?? embed?.username ?? "",
            avatarURL: embed?.avatar_url.flatMap(URL.init(string:)),
            sourceLabel: "Wants to be friends"
        )
    }
}
