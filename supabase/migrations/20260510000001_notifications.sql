-- Apollo Notifications System — v1
-- PRD: Prompts/10-notification-system.md
--
-- Configure these two settings on your Supabase project before applying:
--   ALTER DATABASE postgres SET app.settings.supabase_url TO 'https://YOUR_PROJECT.supabase.co';
--   ALTER DATABASE postgres SET app.settings.service_role_key TO 'YOUR_SERVICE_ROLE_KEY';
-- Then enable extensions and run this migration.

-- ─── Extensions ──────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "pg_net"    WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pg_cron"   WITH SCHEMA extensions;

-- ─── notifications ────────────────────────────────────────────────────────────
-- Stores every in-app notification row (fan-out on write from Edge Function).
-- Retention: 30 days (pg_cron job below).

CREATE TABLE public.notifications (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type        text        NOT NULL,
    actor_id    uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
    post_id     uuid,
    comment_id  uuid,
    payload     jsonb       NOT NULL DEFAULT '{}',
    read_at     timestamptz,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX notifications_user_recency ON public.notifications (user_id, created_at DESC);
CREATE INDEX notifications_unread       ON public.notifications (user_id) WHERE read_at IS NULL;

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own notifications"
    ON public.notifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users update own notifications"
    ON public.notifications FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ─── push_tokens ─────────────────────────────────────────────────────────────
-- APNs device tokens keyed by user. Disabled tokens are retained for audit.

CREATE TABLE public.push_tokens (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    token        text        NOT NULL UNIQUE,
    platform     text        NOT NULL DEFAULT 'ios',
    created_at   timestamptz NOT NULL DEFAULT now(),
    last_seen_at timestamptz,
    disabled_at  timestamptz
);

CREATE INDEX push_tokens_user_active ON public.push_tokens (user_id)
    WHERE disabled_at IS NULL;

ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own push tokens"
    ON public.push_tokens FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- ─── notification_prefs ───────────────────────────────────────────────────────
-- Per-user notification preferences. Default row created on sign-up.

CREATE TABLE public.notification_prefs (
    user_id           uuid    PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    social_enabled    boolean NOT NULL DEFAULT true,
    habit_enabled     boolean NOT NULL DEFAULT true,
    milestone_enabled boolean NOT NULL DEFAULT true,
    north_enabled     boolean NOT NULL DEFAULT true,
    quiet_start       time    NOT NULL DEFAULT '22:00',
    quiet_end         time    NOT NULL DEFAULT '08:00',
    timezone          text    NOT NULL DEFAULT 'America/New_York',
    updated_at        timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_prefs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own prefs"
    ON public.notification_prefs FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Auto-create default prefs row alongside the existing on_auth_user_created trigger.
CREATE OR REPLACE FUNCTION public.create_default_notification_prefs()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notification_prefs (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_create_notification_prefs
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.create_default_notification_prefs();

-- ─── notification_quota ───────────────────────────────────────────────────────
-- Per-user per-day caps (PRD §6): max 20 social, max 2 habit notifications/day.
-- Managed exclusively by the Edge Function (service role); not exposed to clients.

CREATE TABLE public.notification_quota (
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    day          date NOT NULL DEFAULT CURRENT_DATE,
    social_count int  NOT NULL DEFAULT 0,
    habit_count  int  NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, day)
);

ALTER TABLE public.notification_quota ENABLE ROW LEVEL SECURITY;

-- Clients never read or write quota directly; Edge Functions use service role.
CREATE POLICY "No client access to quota"
    ON public.notification_quota FOR ALL
    USING (false);

-- ─── Helper: fire notification event via pg_net ───────────────────────────────
-- Called by triggers. Invokes the notifications-send Edge Function asynchronously.
-- Silently skips if configuration settings are missing (e.g. local dev without pg_net setup).

CREATE OR REPLACE FUNCTION public.fire_notification_event(event_payload jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    _base_url text := current_setting('app.settings.supabase_url', true);
    _svc_key  text := current_setting('app.settings.service_role_key', true);
BEGIN
    IF _base_url IS NULL OR _base_url = '' OR _svc_key IS NULL OR _svc_key = '' THEN
        RETURN;
    END IF;

    PERFORM extensions.net.http_post(
        url     := _base_url || '/functions/v1/notifications-send',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || _svc_key
        ),
        body    := event_payload::text
    );
END;
$$;

-- ─── Trigger: reactions → reaction notification ───────────────────────────────

CREATE OR REPLACE FUNCTION public.on_reaction_insert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    _recipient uuid;
BEGIN
    SELECT user_id INTO _recipient FROM public.posts WHERE id = NEW.post_id;

    -- Skip self-reactions and orphaned posts.
    IF _recipient IS NULL OR _recipient = NEW.user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.fire_notification_event(jsonb_build_object(
        'type',         'reaction',
        'actor_id',     NEW.user_id::text,
        'recipient_id', _recipient::text,
        'post_id',      NEW.post_id::text,
        'emoji',        COALESCE(NEW.emoji, '❤️')
    ));
    RETURN NEW;
END;
$$;

CREATE TRIGGER reaction_notification
    AFTER INSERT ON public.reactions
    FOR EACH ROW EXECUTE FUNCTION public.on_reaction_insert_notify();

-- ─── Trigger: comments → comment / reply notification ────────────────────────

CREATE OR REPLACE FUNCTION public.on_comment_insert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    _recipient  uuid;
    _notif_type text;
BEGIN
    IF NEW.parent_id IS NOT NULL THEN
        -- Reply — notify original commenter.
        SELECT user_id INTO _recipient FROM public.comments WHERE id = NEW.parent_id;
        _notif_type := 'reply';
    ELSE
        -- Top-level comment — notify post owner.
        SELECT user_id INTO _recipient FROM public.posts WHERE id = NEW.post_id;
        _notif_type := 'comment';
    END IF;

    IF _recipient IS NULL OR _recipient = NEW.user_id THEN
        RETURN NEW;
    END IF;

    PERFORM public.fire_notification_event(jsonb_build_object(
        'type',         _notif_type,
        'actor_id',     NEW.user_id::text,
        'recipient_id', _recipient::text,
        'post_id',      NEW.post_id::text,
        'comment_id',   NEW.id::text,
        'body',         LEFT(COALESCE(NEW.body, ''), 50)
    ));
    RETURN NEW;
END;
$$;

CREATE TRIGGER comment_notification
    AFTER INSERT ON public.comments
    FOR EACH ROW EXECUTE FUNCTION public.on_comment_insert_notify();

-- ─── Trigger: friendships → friend_request / friend_accept ───────────────────

CREATE OR REPLACE FUNCTION public.on_friendship_change_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'pending' THEN
        PERFORM public.fire_notification_event(jsonb_build_object(
            'type',         'friend_request',
            'actor_id',     NEW.user_id::text,
            'recipient_id', NEW.friend_id::text
        ));
    ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
        PERFORM public.fire_notification_event(jsonb_build_object(
            'type',         'friend_accept',
            'actor_id',     NEW.friend_id::text,
            'recipient_id', NEW.user_id::text
        ));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER friendship_notification
    AFTER INSERT OR UPDATE ON public.friendships
    FOR EACH ROW EXECUTE FUNCTION public.on_friendship_change_notify();

-- ─── Trigger: posts → first_win_today + milestone_check ──────────────────────

CREATE OR REPLACE FUNCTION public.on_post_insert_notify()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
    _today_count int;
BEGIN
    SELECT COUNT(*) INTO _today_count
    FROM public.posts
    WHERE user_id   = NEW.user_id
      AND post_date = NEW.post_date
      AND deleted_at IS NULL;

    IF _today_count = 1 THEN
        -- First post of the day — notify friends
        PERFORM public.fire_notification_event(jsonb_build_object(
            'type',     'first_win_today',
            'actor_id', NEW.user_id::text,
            'post_id',  NEW.id::text
        ));
        -- Check for streak milestones (7, 30, 100)
        PERFORM public.fire_notification_event(jsonb_build_object(
            'type',     'milestone_check',
            'actor_id', NEW.user_id::text,
            'post_id',  NEW.id::text
        ));
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER post_notification
    AFTER INSERT ON public.posts
    FOR EACH ROW EXECUTE FUNCTION public.on_post_insert_notify();

-- ─── Helper RPC: increment_notification_quota ────────────────────────────────
-- Called by Edge Function after inserting a notification to track daily caps.

CREATE OR REPLACE FUNCTION public.increment_notification_quota(
    p_user_id   uuid,
    p_day       date,
    p_is_social boolean
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
    INSERT INTO public.notification_quota (user_id, day, social_count, habit_count)
    VALUES (p_user_id, p_day, 0, 0)
    ON CONFLICT (user_id, day) DO NOTHING;

    IF p_is_social THEN
        UPDATE public.notification_quota
           SET social_count = social_count + 1
         WHERE user_id = p_user_id AND day = p_day;
    ELSE
        UPDATE public.notification_quota
           SET habit_count = habit_count + 1
         WHERE user_id = p_user_id AND day = p_day;
    END IF;
END;
$$;

-- ─── pg_cron jobs ─────────────────────────────────────────────────────────────

-- 30-day retention: purge old notifications nightly at 3am UTC.
SELECT cron.schedule(
    'apollo-notifications-retention',
    '0 3 * * *',
    $$DELETE FROM public.notifications WHERE created_at < now() - interval '30 days'$$
);

-- Daily quota reset: remove yesterday's quota rows at midnight UTC.
SELECT cron.schedule(
    'apollo-notification-quota-reset',
    '5 0 * * *',
    $$DELETE FROM public.notification_quota WHERE day < CURRENT_DATE$$
);

-- Habit reminders: every 15 minutes, the cron Edge Function evaluates
-- which users need 8pm / 11pm habit notifications.
SELECT cron.schedule(
    'apollo-habit-notifications',
    '*/15 * * * *',
    $$
    SELECT extensions.net.http_post(
        url     := current_setting('app.settings.supabase_url') || '/functions/v1/notifications-cron-streak',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body    := '{}'
    )
    $$
);

-- North weekly summary: Sunday at 9am UTC.
SELECT cron.schedule(
    'apollo-north-weekly',
    '0 9 * * 0',
    $$
    SELECT extensions.net.http_post(
        url     := current_setting('app.settings.supabase_url') || '/functions/v1/notifications-cron-north',
        headers := jsonb_build_object(
            'Content-Type',  'application/json',
            'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body    := '{}'
    )
    $$
);
