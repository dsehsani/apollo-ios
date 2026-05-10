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
    // Photo viewer
    case photoViewerOpened   = "photo_viewer_opened"
    // Camera / capture flow (PRD §Camera)
    case cameraOpened        = "camera_opened"
    case shutterTapped       = "shutter_tapped"
    case usePhotoTapped      = "use_photo_tapped"
    case retakeTapped        = "retake_tapped"
    case privateNoteAdded    = "private_note_added"
    // Memories / Calendar (PRD §11)
    case memoriesOpened      = "memories_opened"
    case calendarTileTapped  = "calendar_tile_tapped"
    case calendarScrolled    = "calendar_scrolled"
    // Friends (PRD §07)
    case friendsOpened       = "friends_opened"
    case requestAccepted     = "request_accepted"
    case requestDeclined     = "request_declined"
    case friendAdded         = "friend_added"
    case inviteCodeCopied    = "invite_code_copied"
    case inviteCodeShared    = "invite_code_shared"
    case searchPerformed     = "search_performed"
    // Notifications (PRD §10)
    case notificationPermissionRequested = "notification_permission_requested"
    case notificationPermissionGranted   = "notification_permission_granted"
    case notificationPermissionDenied    = "notification_permission_denied"
    case notificationTapped              = "notification_tapped"
    case notificationCenterOpened        = "notification_center_opened"
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
