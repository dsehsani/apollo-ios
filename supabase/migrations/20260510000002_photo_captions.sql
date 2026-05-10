-- Per-photo captions
--
-- 1. Add caption column to photos table.
-- 2. Update publish_photo RPC to write p_caption to photos.caption (dual-write:
--    also keeps writing to posts.caption for backward compatibility).
-- 3. Recreate feed_posts view with photo_captions JSON column.

-- ─── 1. photos.caption ───────────────────────────────────────────────────────

ALTER TABLE public.photos ADD COLUMN IF NOT EXISTS caption TEXT;

-- ─── 2. publish_photo RPC ─────────────────────────────────────────────────────
-- Adds caption to the photos INSERT while keeping the posts.caption dual-write.

CREATE OR REPLACE FUNCTION public.publish_photo(
    p_user_id    uuid,
    p_caption    text,
    p_raw_url    text,
    p_win_id     uuid,
    p_captured_at timestamp with time zone,
    p_post_date  date
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_post_id    uuid;
  v_photo_id   uuid;
  v_position   int;
  v_total_wins int;
BEGIN
  -- Upsert today's post (one per user per UTC day).
  INSERT INTO public.posts
    (user_id, post_date, caption, photo_count, win_count, main_photo_url)
  VALUES
    (p_user_id, p_post_date, NULLIF(TRIM(p_caption), ''), 1, 1, p_raw_url)
  ON CONFLICT (user_id, post_date) DO UPDATE
    SET photo_count = posts.photo_count + 1,
        win_count   = posts.win_count   + 1,
        caption     = COALESCE(NULLIF(TRIM(p_caption), ''), posts.caption)
  RETURNING id INTO v_post_id;

  -- Position for the new photo.
  SELECT COALESCE(MAX(position) + 1, 0)
  INTO   v_position
  FROM   public.photos
  WHERE  post_id = v_post_id;

  -- Insert the photo with its own per-photo caption.
  INSERT INTO public.photos
    (post_id, user_id, win_id, raw_url, position, captured_at, caption)
  VALUES
    (v_post_id, p_user_id, p_win_id, p_raw_url, v_position, p_captured_at,
     NULLIF(TRIM(p_caption), ''))
  RETURNING id INTO v_photo_id;

  -- Log a win_completion if linked to a habit/win.
  -- ON CONFLICT DO NOTHING prevents duplicate-key errors when multiple
  -- photos are posted on the same day for the same win.
  IF p_win_id IS NOT NULL THEN
    INSERT INTO public.win_completions
      (win_id, user_id, completed_at, completed_date)
    VALUES
      (p_win_id, p_user_id, p_captured_at, p_post_date)
    ON CONFLICT (win_id, completed_date) DO NOTHING;
  END IF;

  -- Increment lifetime wins counter.
  UPDATE public.users
  SET    total_wins = total_wins + 1
  WHERE  id = p_user_id
  RETURNING total_wins INTO v_total_wins;

  RETURN json_build_object(
    'post_id',    v_post_id,
    'photo_id',   v_photo_id,
    'position',   v_position,
    'total_wins', v_total_wins
  );
END;
$function$;

-- ─── 3. feed_posts view ───────────────────────────────────────────────────────
-- Adds photo_captions: JSON array of per-photo captions ordered by position.
-- Nulls are preserved so the client can align by index with photo_urls.

DROP VIEW IF EXISTS public.feed_posts;

CREATE VIEW public.feed_posts AS
 SELECT p.id,
    p.user_id,
    p.caption,
    p.post_date,
    p.created_at,
    u.username,
    u.handle,
    u.avatar_url,
    p.photo_count,
    p.win_count,
    u.total_wins AS wins_count,
    ( SELECT ph.raw_url
           FROM photos ph
          WHERE ph.post_id = p.id
          ORDER BY ph."position"
         LIMIT 1) AS photo_url,
    ( SELECT json_agg(ph.raw_url ORDER BY ph."position") AS json_agg
           FROM photos ph
          WHERE ph.post_id = p.id) AS photo_urls,
    ( SELECT json_agg(ph.caption ORDER BY ph."position")
           FROM photos ph
          WHERE ph.post_id = p.id) AS photo_captions,
    ( SELECT count(*) AS count
           FROM reactions
          WHERE reactions.post_id = p.id) AS reaction_count,
    ( SELECT count(*) AS count
           FROM comments
          WHERE comments.post_id = p.id) AS comment_count,
    COALESCE(s.current_streak, 0) AS streak
   FROM posts p
     JOIN users u ON u.id = p.user_id
     LEFT JOIN streaks s ON s.user_id = p.user_id;
