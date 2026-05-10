/**
 * notifications-send — Apollo Edge Function
 *
 * Receives a notification event from a DB trigger (via pg_net) or a cron function.
 * Applies dedup, quiet-hours, and daily-cap rules, then:
 *   1. Inserts a row into public.notifications (for in-app center).
 *   2. Sends a push via APNs for each active device token.
 *
 * Called with service-role JWT — bypasses RLS.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { sendApnsPush } from "../_shared/apns.ts";
import {
  buildCopy,
  buildDeepLink,
  NotificationType,
} from "../_shared/copy.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Daily caps per PRD §6.
const SOCIAL_CAP = 20;
const HABIT_CAP = 2;

// Social notification types for quota tracking.
const SOCIAL_TYPES = new Set<NotificationType>([
  "reaction",
  "comment",
  "reply",
  "friend_request",
  "friend_accept",
  "first_win_today",
  "milestone_friend_7",
]);

const HABIT_TYPES = new Set<NotificationType>([
  "habit_no_post",
  "habit_streak_break",
]);

// Types that fan out to friends rather than a single recipient.
const FAN_OUT_TYPES = new Set(["first_win_today", "milestone_friend_7"]);

interface EventPayload {
  type: string;
  actor_id?: string;
  recipient_id?: string;
  post_id?: string;
  comment_id?: string;
  emoji?: string;
  body?: string;
  streak_days?: number;
  win_name?: string;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let event: EventPayload;
  try {
    event = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const type = event.type as NotificationType;
  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    if (type === "milestone_check") {
      await handleMilestoneCheck(db, event);
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    if (FAN_OUT_TYPES.has(type)) {
      await handleFanOut(db, event, type);
      return new Response(JSON.stringify({ ok: true }), { status: 200 });
    }

    if (event.recipient_id) {
      await sendNotification(db, event.recipient_id, event, type);
    }

    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  } catch (err) {
    console.error("notifications-send error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});

// ─── Core send path ──────────────────────────────────────────────────────────

async function sendNotification(
  db: ReturnType<typeof createClient>,
  recipientId: string,
  event: EventPayload,
  type: NotificationType
) {
  // 1. Load prefs.
  const { data: prefs } = await db
    .from("notification_prefs")
    .select("social_enabled, habit_enabled, milestone_enabled, north_enabled, quiet_start, quiet_end, timezone")
    .eq("user_id", recipientId)
    .maybeSingle();

  if (prefs) {
    if (SOCIAL_TYPES.has(type) && !prefs.social_enabled) return;
    if (HABIT_TYPES.has(type) && !prefs.habit_enabled) return;
    if (["milestone_7", "milestone_30", "milestone_100"].includes(type) && !prefs.milestone_enabled) return;
    if (type === "north_weekly" && !prefs.north_enabled) return;

    // Quiet hours check (convert "HH:MM" to minutes since midnight in user's TZ).
    if (isQuietHours(prefs.quiet_start, prefs.quiet_end, prefs.timezone)) {
      return;
    }
  }

  // 2. Daily cap check.
  const today = new Date().toISOString().slice(0, 10);
  const isSocial = SOCIAL_TYPES.has(type);
  const isHabit = HABIT_TYPES.has(type);

  if (isSocial || isHabit) {
    const { data: quota } = await db
      .from("notification_quota")
      .select("social_count, habit_count")
      .eq("user_id", recipientId)
      .eq("day", today)
      .maybeSingle();

    if (isSocial && (quota?.social_count ?? 0) >= SOCIAL_CAP) return;
    if (isHabit && (quota?.habit_count ?? 0) >= HABIT_CAP) return;
  }

  // 3. Dedup: skip if same (user, type, post, actor) within 24h.
  if (event.post_id && event.actor_id) {
    const { data: existing } = await db
      .from("notifications")
      .select("id")
      .eq("user_id", recipientId)
      .eq("type", type)
      .eq("post_id", event.post_id)
      .eq("actor_id", event.actor_id)
      .gte("created_at", new Date(Date.now() - 86_400_000).toISOString())
      .maybeSingle();

    if (existing) return;
  }

  // 4. Load actor display name for copy.
  let actorName: string | undefined;
  if (event.actor_id) {
    const { data: actor } = await db
      .from("users")
      .select("display_name, username")
      .eq("id", event.actor_id)
      .maybeSingle();
    actorName = actor?.display_name || actor?.username;
  }

  // 5. Build copy + deep link.
  const copy = buildCopy(type, {
    actorName,
    body: event.body,
    emoji: event.emoji,
    streakDays: event.streak_days,
    winName: event.win_name,
  });
  const deepLink = buildDeepLink(type, event.post_id);

  // 6. Insert into notifications table.
  const { data: notifRow } = await db.from("notifications").insert({
    user_id:    recipientId,
    type,
    actor_id:   event.actor_id ?? null,
    post_id:    event.post_id ?? null,
    comment_id: event.comment_id ?? null,
    payload: {
      title:     copy.title,
      body:      copy.body,
      deep_link: deepLink,
    },
  }).select("id").single();

  // 7. Increment quota.
  if (isSocial || isHabit) {
    await db.rpc("increment_notification_quota", {
      p_user_id:   recipientId,
      p_day:       today,
      p_is_social: isSocial,
    });
  }

  // 8. Load active push tokens and send APNs.
  const { data: tokens } = await db
    .from("push_tokens")
    .select("id, token")
    .eq("user_id", recipientId)
    .is("disabled_at", null);

  if (!tokens?.length) return;

  // Determine interruption level: passive between 10pm–8am.
  const inQuietWindow = isQuietWindow(prefs?.quiet_start ?? "22:00", prefs?.quiet_end ?? "08:00", prefs?.timezone ?? "UTC");
  const interruptionLevel = inQuietWindow ? "passive" : "active";

  await Promise.all(
    tokens.map(async (t: { id: string; token: string }) => {
      const result = await sendApnsPush(t.token, {
        alert: { title: copy.title, body: copy.body },
        data:  { deep_link: deepLink, notification_id: notifRow?.id ?? "" },
        collapseId: `${type}-${event.post_id ?? event.actor_id ?? ""}`,
        interruptionLevel,
      });

      if (result.unregistered) {
        await db
          .from("push_tokens")
          .update({ disabled_at: new Date().toISOString() })
          .eq("id", t.id);
      }
    })
  );
}

// ─── Fan-out: first_win_today / milestone_friend_7 ───────────────────────────

async function handleFanOut(
  db: ReturnType<typeof createClient>,
  event: EventPayload,
  type: NotificationType
) {
  if (!event.actor_id) return;

  // Load all accepted friends of actor.
  const { data: friendships } = await db
    .from("friendships")
    .select("friend_id")
    .eq("user_id", event.actor_id)
    .eq("status", "accepted");

  if (!friendships?.length) return;

  await Promise.all(
    friendships.map((f: { friend_id: string }) =>
      sendNotification(db, f.friend_id, event, type)
    )
  );
}

// ─── Milestone check (triggered by post insert) ───────────────────────────────

async function handleMilestoneCheck(
  db: ReturnType<typeof createClient>,
  event: EventPayload
) {
  if (!event.actor_id) return;

  // Fetch user's current streak from their profile view.
  const { data: profile } = await db
    .from("profile_users")
    .select("current_streak")
    .eq("id", event.actor_id)
    .maybeSingle();

  const streak: number = profile?.current_streak ?? 0;
  const milestones: Record<number, NotificationType> = {
    7: "milestone_7",
    30: "milestone_30",
    100: "milestone_100",
  };
  const milestoneType = milestones[streak];
  if (!milestoneType) return;

  // Dedup: only once per milestone (check if we already sent this).
  const { data: existing } = await db
    .from("notifications")
    .select("id")
    .eq("user_id", event.actor_id)
    .eq("type", milestoneType)
    .limit(1)
    .maybeSingle();

  if (existing) return;

  await sendNotification(db, event.actor_id, event, milestoneType);

  // Also notify friends about friend milestone (7-day only per PRD §13).
  if (streak === 7) {
    await handleFanOut(db, { ...event, type: "milestone_friend_7" }, "milestone_friend_7");
  }
}

// ─── Quiet-hours helpers ─────────────────────────────────────────────────────

function isQuietHours(quietStart: string, quietEnd: string, tz: string): boolean {
  return isQuietWindow(quietStart, quietEnd, tz);
}

function isQuietWindow(quietStart: string, quietEnd: string, tz: string): boolean {
  try {
    const now = new Date();
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
    const [hourStr, minStr] = formatter.format(now).split(":");
    const currentMinutes = parseInt(hourStr) * 60 + parseInt(minStr);

    const [startH, startM] = quietStart.split(":").map(Number);
    const [endH, endM] = quietEnd.split(":").map(Number);
    const startMin = startH * 60 + startM;
    const endMin = endH * 60 + endM;

    // Handle wrap-around (e.g. 22:00–08:00).
    if (startMin > endMin) {
      return currentMinutes >= startMin || currentMinutes < endMin;
    }
    return currentMinutes >= startMin && currentMinutes < endMin;
  } catch {
    return false;
  }
}
