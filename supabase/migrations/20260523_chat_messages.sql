-- ============================================================================
-- CMANDILI — Backfill migration: AI Chat message history (`chat_messages`).
--
-- This table was applied directly via the Supabase SQL Editor on 2026-05-23
-- (see cmandili_context.md / RESUME.md §7.5) and was never captured as a
-- migration file. It IS already live in production — this file exists only
-- so the repo's migration history matches reality; it changes nothing when
-- run against the current database (all statements are idempotent).
--
-- Verified against the live schema (via PostgREST OpenAPI introspection,
-- 2026-08-09): columns match exactly — id, user_id, text, is_user, created_at.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chat_messages (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text       text        NOT NULL,
  is_user    boolean     NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS chat_messages_user_id_created_at_idx
  ON public.chat_messages (user_id, created_at DESC);

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own chat messages" ON public.chat_messages;
CREATE POLICY "Users read own chat messages"
  ON public.chat_messages FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users insert own chat messages" ON public.chat_messages;
CREATE POLICY "Users insert own chat messages"
  ON public.chat_messages FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users delete own chat messages" ON public.chat_messages;
CREATE POLICY "Users delete own chat messages"
  ON public.chat_messages FOR DELETE USING (auth.uid() = user_id);
