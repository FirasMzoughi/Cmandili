-- ============================================================================
-- CMANDILI — Push notifications: geo fan-out for new "ready" orders + GUCs.
-- Safe to re-run (idempotent).
-- ============================================================================

-- ── 1. Database GUCs the trigger notify_fcm_on_order_status() reads ──────────
-- These persist across sessions. You MUST replace the placeholder values below
-- with your own project values before the trigger can call the edge function.
--
--   <project-ref>  → the subdomain in your SUPABASE_URL
--                    (e.g. 'hoqlxxtphskgxktqjpfu' in
--                     https://hoqlxxtphskgxktqjpfu.supabase.co)
--   <anon-key>     → your Supabase anon/publishable key
--
-- Uncomment + edit, then run manually via the Supabase SQL editor. We keep them
-- commented here so this migration can be re-applied without re-broadcasting
-- the wrong value.
--
-- ALTER DATABASE postgres
--   SET app.edge_function_url = 'https://<project-ref>.supabase.co/functions/v1/push-on-order-status';
-- ALTER DATABASE postgres
--   SET app.edge_function_secret = '<anon-key>';


-- ── 2. Haversine distance helper (km) ────────────────────────────────────────
-- We use a lightweight SQL formula so we don't need the PostGIS extension.
-- Accuracy is sufficient for "within X km of pickup" matching.

CREATE OR REPLACE FUNCTION public.haversine_km(
  lat1 DOUBLE PRECISION,
  lng1 DOUBLE PRECISION,
  lat2 DOUBLE PRECISION,
  lng2 DOUBLE PRECISION
) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT 2 * 6371 * asin(sqrt(
    power(sin(radians(lat2 - lat1) / 2), 2) +
    cos(radians(lat1)) * cos(radians(lat2)) *
    power(sin(radians(lng2 - lng1) / 2), 2)
  ));
$$;


-- ── 3. RPC: drivers currently online within N km of a point ──────────────────
-- Returns the drivers.user_id (owners of device_tokens) so the edge function
-- can look up FCM tokens directly.

CREATE OR REPLACE FUNCTION public.nearby_online_drivers(
  p_lat DOUBLE PRECISION,
  p_lng DOUBLE PRECISION,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS TABLE(user_id UUID, distance_km DOUBLE PRECISION)
LANGUAGE sql SECURITY DEFINER AS $$
  SELECT
    d.user_id,
    public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) AS distance_km
  FROM public.drivers d
  WHERE d.is_online = true
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND public.haversine_km(p_lat, p_lng, d.current_lat, d.current_lng) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT 50;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_online_drivers(DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION)
  TO anon, authenticated, service_role;


-- ── 4. Trigger extension: fan out a "new order" FCM when status = 'ready' ────
-- The existing notify_fcm_on_order_status trigger (in cmandili_schema.sql §23)
-- only notifies the order owner. Drivers need a separate broadcast. We post a
-- dedicated event that the edge function routes to nearby drivers using the
-- pickup lat/lng from the order's restaurant or supermarket.

CREATE OR REPLACE FUNCTION public.notify_fcm_fanout_ready_order()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := current_setting('app.edge_function_url',    true);
  v_secret TEXT := current_setting('app.edge_function_secret', true);
BEGIN
  IF NEW.status = 'ready'
     AND (OLD.status IS DISTINCT FROM 'ready')
     AND v_url IS NOT NULL AND v_url != ''
  THEN
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


-- ── Done ─────────────────────────────────────────────────────────────────────
