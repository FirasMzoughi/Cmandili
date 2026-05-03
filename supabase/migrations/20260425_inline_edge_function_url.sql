-- ============================================================================
-- CMANDILI — Trigger functions that POST to the push-on-order-status edge
-- function whenever an order's status changes (or a partner marks it ready).
--
-- Configuration: each function reads the edge function URL and bearer token
-- from session GUCs (`app.edge_function_url`, `app.edge_function_secret`).
-- A migration (20260426_set_edge_function_settings.sql) sets these via
-- `ALTER DATABASE ... SET ...`. If that ALTER is blocked on Supabase Cloud
-- the GUCs will be NULL and the trigger will fall back to the inline values
-- below. Replace the inline fallbacks with your project's real URL + anon
-- key before applying in production.
--
-- The `secret` is the anon (publishable) key, which is already exposed to
-- every Flutter client — it's not actually a secret.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.notify_fcm_on_order_status()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
BEGIN
  IF NEW.status != OLD.status THEN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_status_push ON public.orders;
CREATE TRIGGER on_order_status_push
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_fcm_on_order_status();


CREATE OR REPLACE FUNCTION public.notify_fcm_fanout_ready_order()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := COALESCE(
    current_setting('app.edge_function_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-on-order-status'
  );
  v_secret TEXT := COALESCE(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
BEGIN
  IF NEW.status = 'ready' AND (OLD.status IS DISTINCT FROM 'ready') THEN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'event',     'driver_fanout',
        'order_id',  NEW.id,
        'status',    NEW.status
      )
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_ready_driver_fanout ON public.orders;
CREATE TRIGGER on_order_ready_driver_fanout
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_fcm_fanout_ready_order();
