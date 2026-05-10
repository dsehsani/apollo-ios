/**
 * Notification copy templates — mirrors PRD §2.
 * All text is in English (v1). Future: move to DB for A/B testing.
 */

export interface NotificationCopy {
  title: string;
  body: string;
}

export type NotificationType =
  | "reaction"
  | "comment"
  | "reply"
  | "friend_request"
  | "friend_accept"
  | "first_win_today"
  | "milestone_7"
  | "milestone_30"
  | "milestone_100"
  | "milestone_friend_7"
  | "habit_no_post"
  | "habit_streak_break"
  | "win_reminder"
  | "north_weekly";

interface CopyParams {
  actorName?: string;
  body?: string;
  emoji?: string;
  streakDays?: number;
  winName?: string;
}

export function buildCopy(
  type: NotificationType,
  params: CopyParams = {}
): NotificationCopy {
  const name = params.actorName ?? "Someone";
  const emoji = params.emoji ?? "❤️";
  const streak = params.streakDays ?? 0;
  const winName = params.winName ?? "your win";

  switch (type) {
    case "reaction":
      return {
        title: `${emoji} ${name}`,
        body: `${name} sent you a ${emoji}`,
      };

    case "comment":
      return {
        title: name,
        body: params.body
          ? `${name}: ${params.body}`
          : `${name} commented on your post.`,
      };

    case "reply":
      return {
        title: name,
        body: params.body
          ? `${name} replied: ${params.body}`
          : `${name} replied to your comment.`,
      };

    case "friend_request":
      return {
        title: `${name} wants to connect`,
        body: `${name} sent you a friend request.`,
      };

    case "friend_accept":
      return {
        title: name,
        body: `You and ${name} are now friends on Apollo.`,
      };

    case "first_win_today":
      return {
        title: `${name} is winning`,
        body: `${name} just posted their first win today.`,
      };

    case "milestone_7":
      return {
        title: "Day 7.",
        body: "A full week. That's how habits start.",
      };

    case "milestone_30":
      return {
        title: "Day 30.",
        body: "One month of winning every day.",
      };

    case "milestone_100":
      return {
        title: "Day 100.",
        body: "You're not the same person you were 100 days ago.",
      };

    case "milestone_friend_7":
      return {
        title: `${name} hit 7 days`,
        body: `${name} has been winning every day for a week.`,
      };

    case "habit_no_post":
      return {
        title: "Win every day.",
        body: "You haven't posted today.",
      };

    case "habit_streak_break":
      return {
        title: "Don't break it.",
        body: `${streak} days in a row. Keep it alive.`,
      };

    case "win_reminder":
      return {
        title: winName,
        body: "Time to win.",
      };

    case "north_weekly":
      return {
        title: "Your week, from North.",
        body: "7 days of data. North has something to say.",
      };
  }
}

/** Deep link path per notification type (PRD §2 "Deep Link" column). */
export function buildDeepLink(
  type: NotificationType,
  postId?: string,
  openComments = false
): string {
  switch (type) {
    case "reaction":
      return postId ? `apollo://feed/post/${postId}` : "apollo://feed";
    case "comment":
    case "reply":
      return postId
        ? `apollo://feed/post/${postId}?openComments=1`
        : "apollo://feed";
    case "friend_request":
    case "friend_accept":
      return "apollo://friends";
    case "first_win_today":
      return postId ? `apollo://feed/post/${postId}` : "apollo://feed";
    case "milestone_7":
    case "milestone_30":
    case "milestone_100":
    case "milestone_friend_7":
      return postId ? `apollo://feed/post/${postId}` : "apollo://feed";
    case "habit_no_post":
    case "habit_streak_break":
    case "win_reminder":
      return "apollo://feed";
    case "north_weekly":
      return "apollo://north";
  }
}
