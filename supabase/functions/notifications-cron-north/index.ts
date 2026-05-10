/**
 * notifications-cron-north — Apollo Edge Function
 *
 * Scheduled every Sunday at 9am UTC via pg_cron.
 * Sends the North weekly summary notification to all users who have
 * north_enabled = true.
 *
 * PRD §2 North Notifications:
 *   Title: "Your week, from North."
 *   Body:  "7 days of data. North has something to say."
 *   Timing: Sunday 9am local
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const sendUrl = supabaseUrl + "/functions/v1/notifications-send";

Deno.serve(async () => {
  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  // All users with North notifications enabled.
  const { data: prefs, error } = await db
    .from("notification_prefs")
    .select("user_id, north_enabled, timezone")
    .eq("north_enabled", true);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  const now = new Date();
  const tasks: Promise<unknown>[] = [];

  for (const pref of prefs ?? []) {
    // Only send when local time is within ±30 minutes of 9am on Sunday.
    const localMinutes = getLocalMinutes(now, pref.timezone);
    const localDay = getLocalDayOfWeek(now, pref.timezone);
    const isSunday = localDay === 0;
    const nearNineAm = Math.abs(localMinutes - 9 * 60) <= 30;

    if (!isSunday || !nearNineAm) continue;

    tasks.push(
      fetch(sendUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          type: "north_weekly",
          recipient_id: pref.user_id,
        }),
      })
    );
  }

  await Promise.allSettled(tasks);
  return new Response(JSON.stringify({ sent: tasks.length }), { status: 200 });
});

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

function getLocalDayOfWeek(date: Date, tz: string): number {
  try {
    const formatter = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      weekday: "short",
    });
    const day = formatter.format(date);
    return ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(day);
  } catch {
    return -1;
  }
}
