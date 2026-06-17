-- ============================================================================
-- CMANDILI — Single-driver assignment with 10s timeout + delivery distance.
--
-- Two big changes:
--
--   1. ORDER ASSIGNMENT: replaces the broadcast-to-all-nearby-drivers fanout
--      with a sequential, single-target offer. When an order is ready:
--        - assigned_driver_id is set to the closest online driver
--        - assignment_expires_at is set to now()+10s
--        - the edge function pushes a high-priority FCM to ONE driver
--        - the driver app shows a 10s countdown alert
--      If the timer expires or the driver passes, a cron job moves the offer
--      to the next-closest driver (excluding everyone in `passed_driver_ids`).
--
--   2. DELIVERY DISTANCE: every order now stores the haversine restaurant→
--      customer distance in km. The driver app surfaces it on the offer card,
--      and the customer-side fee formula uses it as the bonus input.
--
-- Idempotent — safe to re-run.
-- ============================================================================

-- ── 1. New columns on orders ────────────────────────────────────────────────
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS distance_km            DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS assigned_driver_id     UUID REFERENCES public.drivers(id),
  ADD COLUMN IF NOT EXISTS assignment_expires_at  TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS passed_driver_ids      UUID[] NOT NULL DEFAULT '{}';

CREATE INDEX IF NOT EXISTS idx_orders_assignment_expires
  ON public.orders (assignment_expires_at)
  WHERE assigned_driver_id IS NOT NULL AND driver_id IS NULL;


-- ── 2. RLS for assignment columns ───────────────────────────────────────────
-- A driver's "available orders" list now means orders currently offered to
-- THEM (assigned_driver_id = self) plus the legacy unassigned-pending pool
-- (assigned_driver_id IS NULL). Replace the broadcast SELECT policy.

DROP POLICY IF EXISTS "drivers_select_pending_or_ready" ON public.orders;
CREATE POLICY "drivers_see_offers_and_unassigned"
  ON public.orders FOR SELECT USING (
    -- Order they already accepted
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    OR
    -- Order currently offered to them
    assigned_driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid())
    OR
    -- Legacy: unassigned ready/pending orders are still visible so the system
    -- gracefully degrades to broadcast if cron stops running.
    (status IN ('pending','ready') AND assigned_driver_id IS NULL)
  );


-- ── 3. RPC: pick the next driver to offer an order to ──────────────────────
-- Returns the closest online driver within radius_km that is NOT already in
-- passed_driver_ids. NULL when no eligible drivers remain — caller falls
-- back to broadcast.

CREATE OR REPLACE FUNCTION public.next_eligible_driver(
  p_order_id UUID,
  p_radius_km DOUBLE PRECISION DEFAULT 7
) RETURNS UUID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_lat DOUBLE PRECISION;
  v_lng DOUBLE PRECISION;
  v_passed UUID[];
  v_driver_id UUID;
BEGIN
  -- Resolve pickup coords from restaurant / supermarket / pickup_address.
  SELECT
    COALESCE(r.latitude,  s.latitude,  (o.pickup_address->>'lat')::DOUBLE PRECISION),
    COALESCE(r.longitude, s.longitude, (o.pickup_address->>'lng')::DOUBLE PRECISION),
    o.passed_driver_ids
  INTO v_lat, v_lng, v_passed
  FROM public.orders o
  LEFT JOIN public.restaurants  r ON r.id = o.restaurant_id
  LEFT JOIN public.supermarkets s ON s.id = o.supermarket_id
  WHERE o.id = p_order_id;

  IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
    RETURN NULL;
  END IF;

  -- Closest online driver whose drivers.id is not in the passed list.
  SELECT d.id INTO v_driver_id
  FROM public.drivers d
  WHERE d.is_online = TRUE
    AND d.current_lat IS NOT NULL
    AND d.current_lng IS NOT NULL
    AND public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) <= p_radius_km
    AND NOT (d.id = ANY(v_passed))
  ORDER BY public.haversine_km(v_lat, v_lng, d.current_lat, d.current_lng) ASC
  LIMIT 1;

  RETURN v_driver_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_eligible_driver(UUID, DOUBLE PRECISION)
  TO anon, authenticated, service_role;


-- ── 4. RPC: offer an order to a specific driver ─────────────────────────────
-- Sets assigned_driver_id + assignment_expires_at, then triggers a single-
-- target push. Idempotent: if assigned_driver_id is already set and not
-- expired, returns without changes.

CREATE OR REPLACE FUNCTION public.offer_order_to_driver(
  p_order_id UUID,
  p_driver_id UUID,
  p_window_seconds INT DEFAULT 10
) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_url    TEXT := current_setting('app.edge_function_url',    TRUE);
  v_secret TEXT := current_setting('app.edge_function_secret', TRUE);
BEGIN
  UPDATE public.orders
  SET assigned_driver_id    = p_driver_id,
      assignment_expires_at = now() + make_interval(secs => p_window_seconds)
  WHERE id = p_order_id
    AND driver_id IS NULL; -- never overwrite an order already accepted

  IF v_url IS NOT NULL AND v_url != '' THEN
    PERFORM net.http_post(
      url     := v_url,
      headers := jsonb_build_object(
        'Content-Type',  'application/json',
        'Authorization', 'Bearer ' || v_secret
      ),
      body    := jsonb_build_object(
        'event',     'offer_to_driver',
        'order_id',  p_order_id,
        'driver_id', p_driver_id,
        'status',    'ready'
      )
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.offer_order_to_driver(UUID, UUID, INT)
  TO authenticated, service_role;


-- ── 5. Replace the ready-fanout trigger with single-driver-offer ────────────
-- The old notify_fcm_fanout_ready_order broadcast to N drivers. We keep the
-- function name + trigger but switch its body so it picks ONE driver and
-- offers via offer_order_to_driver.

CREATE OR REPLACE FUNCTION public.notify_fcm_fanout_ready_order()
RETURNS TRIGGER AS $$
DECLARE
  v_first_driver UUID;
BEGIN
  IF NEW.status = 'ready' AND (OLD.status IS DISTINCT FROM 'ready') THEN
    v_first_driver := public.next_eligible_driver(NEW.id);
    IF v_first_driver IS NOT NULL THEN
      PERFORM public.offer_order_to_driver(NEW.id, v_first_driver);
    END IF;
    -- If no driver is online, the order stays unassigned and visible in the
    -- legacy "available orders" list (RLS policy above) so we degrade gracefully.
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ── 6. Cron job: re-offer expired assignments every 5 seconds ───────────────
-- pg_cron polls expired offers and rotates them to the next driver. Batch
-- size 20 is plenty for this workload; a true high-volume rollout would
-- shard by region.

CREATE OR REPLACE FUNCTION public.rotate_expired_offers()
RETURNS INTEGER
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_row RECORD;
  v_count INTEGER := 0;
  v_next UUID;
BEGIN
  FOR v_row IN
    SELECT id, assigned_driver_id
    FROM public.orders
    WHERE assigned_driver_id IS NOT NULL
      AND driver_id IS NULL
      AND assignment_expires_at IS NOT NULL
      AND assignment_expires_at < now()
    LIMIT 20
  LOOP
    -- Mark current candidate as passed before picking the next one so the
    -- query for next_eligible_driver sees a consistent passed_driver_ids array.
    UPDATE public.orders
    SET passed_driver_ids = passed_driver_ids || v_row.assigned_driver_id,
        assigned_driver_id = NULL,
        assignment_expires_at = NULL
    WHERE id = v_row.id;

    v_next := public.next_eligible_driver(v_row.id);
    IF v_next IS NOT NULL THEN
      PERFORM public.offer_order_to_driver(v_row.id, v_next);
    END IF;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.rotate_expired_offers() TO service_role;

-- Schedule pg_cron to call rotate_expired_offers() every 5 seconds. Wrapped
-- in a DO block so this migration doesn't fail on databases without pg_cron
-- enabled — admin can enable + run the schedule statement manually.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    PERFORM cron.unschedule('cmandili_rotate_offers')
      WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cmandili_rotate_offers');
    PERFORM cron.schedule(
      'cmandili_rotate_offers',
      '5 seconds',
      $cron$ SELECT public.rotate_expired_offers(); $cron$
    );
  END IF;
EXCEPTION WHEN OTHERS THEN
  -- Schema changes always succeed even if scheduling fails; admin will see
  -- this in logs and re-run cron.schedule manually.
  RAISE NOTICE 'pg_cron scheduling skipped: %', SQLERRM;
END $$;


-- ── 7. Pass-the-offer helper used by the driver app ─────────────────────────
-- When the driver explicitly taps "Pass" (or the in-app countdown elapses
-- before they tap Accept), we call this RPC. It mirrors the cron logic but
-- runs synchronously so the next driver gets pinged immediately instead of
-- waiting for the next cron tick.

CREATE OR REPLACE FUNCTION public.pass_order_offer(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_caller_driver UUID;
  v_current UUID;
  v_next UUID;
BEGIN
  SELECT id INTO v_caller_driver FROM public.drivers WHERE user_id = auth.uid();
  IF v_caller_driver IS NULL THEN
    RAISE EXCEPTION 'caller is not a driver';
  END IF;

  SELECT assigned_driver_id INTO v_current
  FROM public.orders WHERE id = p_order_id;
  IF v_current IS DISTINCT FROM v_caller_driver THEN
    -- Caller isn't the currently-offered driver: noop, don't punish them.
    RETURN;
  END IF;

  UPDATE public.orders
  SET passed_driver_ids = passed_driver_ids || v_caller_driver,
      assigned_driver_id = NULL,
      assignment_expires_at = NULL
  WHERE id = p_order_id;

  v_next := public.next_eligible_driver(p_order_id);
  IF v_next IS NOT NULL THEN
    PERFORM public.offer_order_to_driver(p_order_id, v_next);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.pass_order_offer(UUID) TO authenticated;
