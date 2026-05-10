//
//  Analytics.swift
//  Apollo
//
//  Minimal analytics layer. In production this would forward events to a backend
//  (Amplitude, Mixpanel, PostHog, etc.). For now it prints in DEBUG builds.
//

import Foundation

enum AnalyticsEvent: String {
    case postReactionAdded   = "post_reaction_added"
    case postReactionRemoved = "post_reaction_removed"
    case breakdownOpened     = "breakdown_opened"
    case breakdownFiltered   = "breakdown_filtered"
    case customEmojiUsed     = "custom_emoji_used"
    // Comments (PRD §09 §11)
    case commentsOpened      = "comments_opened"
    case commentSubmitted    = "comment_submitted"
    case commentDeleted      = "comment_deleted"
    case replyStarted        = "reply_started"
}

enum Analytics {
    static func track(_ event: AnalyticsEvent, _ properties: [String: Any] = [:]) {
#if DEBUG
        var parts = ["[analytics]", event.rawValue]
        if !properties.isEmpty {
            let formatted = properties.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            parts.append(formatted)
        }
        print(parts.joined(separator: " "))
#endif
    }
}
