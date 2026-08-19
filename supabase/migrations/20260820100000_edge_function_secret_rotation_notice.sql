-- ============================================================================
-- CMANDILI — ACTION REQUIRED: rotate app.edge_function_secret off the anon key.
--
-- Bug: push-on-order-status (supabase/functions/push-on-order-status/index.ts)
-- was reachable by anyone holding the public Supabase anon/publishable key —
-- which is compiled into every shipped Flutter app and meant to be public.
-- The DB triggers in 20260425_inline_edge_function_url.sql and
-- 20260426_set_edge_function_settings.sql authenticated to the edge function
-- using that same anon key as the "shared secret," and `verify_jwt = true`
-- (config.toml) only checks that *some* valid Supabase JWT is present, which
-- the anon key satisfies. Net effect: no real access control — anyone could
-- POST directly to the function and spam arbitrary users with pushes
-- (forged order-status updates, repeated driver "10s to accept" alarms, a
-- forced fan-out to every nearby driver, etc), with no idempotency guard.
--
-- The edge function has been updated to require a real, independent shared
-- secret via a new TRIGGER_SHARED_SECRET env var (fails closed — returns 401
-- if that var isn't set, rather than silently trusting any JWT). This
-- migration cannot complete the fix by itself: it has no way to run
-- `supabase secrets set` or reach a superuser session to ALTER DATABASE.
--
-- ── Steps to finish this fix (run once, outside of migrations) ─────────────
--   1. Generate a real secret:      openssl rand -hex 32
--   2. Set it on the edge function: supabase secrets set TRIGGER_SHARED_SECRET=<value>
--   3. Point the DB triggers at the same value — from a privileged session
--      (Supabase Cloud: SQL Editor as postgres/superuser, or open a support
--      ticket if ALTER DATABASE is blocked for your project):
--        ALTER DATABASE postgres SET app.edge_function_secret = '<value>';
--   4. Redeploy the function:       supabase functions deploy push-on-order-status
--   5. Verify: an unauthenticated POST to the function's invoke URL should
--      now return 401 instead of sending pushes.
--
-- Until step 3 is done, the DB triggers still send the old anon-key value as
-- their bearer token, so their pushes will also 401 — legitimate order-status
-- notifications will silently stop going out. Do steps 2–4 together in one
-- deploy window to avoid a gap.
--
-- This migration makes no schema/data changes — it exists purely as a
-- tracked, dated record of the required manual step, since the fix cannot
-- be expressed as ordinary SQL.
-- ============================================================================

DO $$
BEGIN
  RAISE NOTICE 'push-on-order-status: rotate app.edge_function_secret off the '
               'public anon key and set TRIGGER_SHARED_SECRET on the edge '
               'function. See this migration file for the exact steps.';
END$$;
