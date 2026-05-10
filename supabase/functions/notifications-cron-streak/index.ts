/**
 * notifications-cron-streak — Apollo Edge Function
 *
 * Scheduled every 15 minutes via pg_cron.
 * For each user whose local time is within ±8 minutes of 8pm or 11pm,
 * checks whether they have posted today and sends the appropriate habit notification.
 *
 * 8pm:  "Win every day." — "You haven't posted today." (PRD §2 habit table row 1)
 * 11pm: "Don't break it." — "{X} days in a row. Keep it alive." (row 2)
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sendUrl = supabaseUrl + "/functions/v1/notifications-send";

Deno.serve(async () => {
  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  // Load all users' prefs + timezones so we can check local time.
  const { data: allPrefs, error } = await db
    .from("notification_prefs")
    .select("user_id, habit_enabled, timezone");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const now = new Date();
  const tasks: Promise<unknown>[] = [];

  for (const pref of allPrefs ?? []) {
    if (!pref.habit_enabled) continue;

    const localMinutes = getLocalMinutes(now, pref.timezone);
    const targetEight = 20 * 60;   // 8pm
    const targetEleven = 23 * 60;  // 11pm
    const window = 8; // ±8 minutes

    const nearEight  = Math.abs(localMinutes - targetEight)  <= window;
    const nearEleven = Math.abs(localMinutes - targetEleven) <= window;

    if (!nearEight && !nearEleven) continue;

    tasks.push(handleUserStreak(db, pref.user_id, nearEleven));
  }

  await Promise.allSettled(tasks);
  return new Response(JSON.stringify({ processed: tasks.length }), { status: 200 });
});

async function handleUserStreak(
  db: ReturnType<typeof createClient>,
  userId: string,
  isElevenPm: boolean
) {
  // Check if user has posted today (UTC date).
  const today = new Date().toISOString().slice(0, 10);
  const { count } = await db
    .from("posts")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("post_date", today)
    .is("deleted_at", null);

  const hasPostedToday = (count ?? 0) > 0;
  if (hasPostedToday) return; // Both 8pm and 11pm notifications suppressed.

  // At 11pm also check streak length.
  let streakDays = 0;
  if (isElevenPm) {
    const { data: profile } = await db
      .from("profile_users")
      .select("current_streak")
      .eq("id", userId)
      .maybeSingle();
    streakDays = profile?.current_streak ?? 0;
    if (streakDays === 0) return; // No streak to protect.
  }

  const payload = isElevenPm
    ? { type: "habit_streak_break", recipient_id: userId, streak_days: streakDays }
    : { type: "habit_no_post",     recipient_id: userId };

  await fetch(sendUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${serviceRoleKey}`,
    },
    body: JSON.stringify(payload),
  });
}

function getLocalMinutes(date: Date, tz: string): number {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      hour: "2-digit",
      minute: "2-digit",
      hour12: false,
    });
    const [h, m] = formatter.format(date).split(":").map(Number);
    return h * 60 + m;
  } catch {
    return 0;
  }
}
