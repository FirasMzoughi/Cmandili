-- ============================================================================
-- CMANDILI — Persist the edge function URL + bearer token as database GUCs.
--
-- The trigger functions in 20260425_inline_edge_function_url.sql read these
-- via `current_setting('app.edge_function_url', true)` and fall back to
-- inline constants if NULL. Setting them here lets you change values per
-- environment without editing the trigger functions.
--
-- NOTE: `ALTER DATABASE postgres SET ...` requires superuser. On Supabase
-- Cloud the SQL editor session is NOT a superuser, so the ALTER below will
-- fail with `permission denied`. The DO block traps that error so the
-- migration still succeeds — the trigger functions will then use their
-- inline fallbacks. If you need to override the values on Supabase Cloud,
-- open a support ticket or run this from a privileged psql session.
-- ============================================================================

DO $$
BEGIN
  EXECUTE format(
    'ALTER DATABASE %I SET app.edge_function_url = %L',
    current_database(),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  EXECUTE format(
    'ALTER DATABASE %I SET app.edge_function_secret = %L',
    current_database(),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'ALTER DATABASE blocked (non-superuser session). '
                 'Trigger functions will use inline fallbacks. '
                 'Override per-environment via a privileged session if needed.';
END$$;
