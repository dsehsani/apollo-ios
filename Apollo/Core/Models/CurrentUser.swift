//
//  CurrentUser.swift
//  Apollo
//
//  Lightweight value type representing the signed-in user's profile fields.
//  Held by SessionStore and passed down to screens that need the current
//  user's identity (e.g. comments input bar, optimistic comment rows).
//

import Foundation

struct CurrentUser: Sendable, Hashable {
    let id: UUID
    let username: String
    let avatarURL: URL?
}
