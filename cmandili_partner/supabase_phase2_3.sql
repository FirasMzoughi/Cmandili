-- ============================================================================
-- CMANDILI — Phase 2 & 3 migrations. Idempotent. Run in Supabase SQL editor.
-- ============================================================================

-- ── 1. reviews ───────────────────────────────────────────────────────────────
-- Stores customer ratings for restaurants and supermarkets.
-- entity_id references either restaurants.id or supermarkets.id.

CREATE TABLE IF NOT EXISTS public.reviews (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_id   UUID NOT NULL,
  entity_type TEXT NOT NULL CHECK (entity_type IN ('restaurant', 'supermarket')),
  rating      SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  order_id    UUID REFERENCES public.orders(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS reviews_user_order_idx
  ON public.reviews(user_id, order_id)
  WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS reviews_entity_idx ON public.reviews(entity_id);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews_insert" ON public.reviews;
CREATE POLICY "reviews_insert"
  ON public.reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reviews_select" ON public.reviews;
CREATE POLICY "reviews_select"
  ON public.reviews FOR SELECT
  USING (true); -- public read

DROP POLICY IF EXISTS "reviews_delete_own" ON public.reviews;
CREATE POLICY "reviews_delete_own"
  ON public.reviews FOR DELETE
  USING (auth.uid() = user_id);


-- ── 2. partner_payout_info ───────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partner_payout_info (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  account_holder TEXT NOT NULL DEFAULT '',
  bank_name      TEXT NOT NULL DEFAULT '',
  iban           TEXT NOT NULL DEFAULT '',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.partner_payout_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "partner_payout_rw" ON public.partner_payout_info;
CREATE POLICY "partner_payout_rw"
  ON public.partner_payout_info FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ── 3. driver_payout_info ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.driver_payout_info (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  account_holder TEXT NOT NULL DEFAULT '',
  bank_name      TEXT NOT NULL DEFAULT '',
  iban           TEXT NOT NULL DEFAULT '',
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.driver_payout_info ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "driver_payout_rw" ON public.driver_payout_info;
CREATE POLICY "driver_payout_rw"
  ON public.driver_payout_info FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ── 4. drivers — add vehicle columns & is_online ────────────────────────────
-- These are added with IF NOT EXISTS so re-running is safe.

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS is_online       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS vehicle_type    TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_make    TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_model   TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_plate   TEXT,
  ADD COLUMN IF NOT EXISTS vehicle_color   TEXT;


-- ── 5. orders — add prep timestamp columns ───────────────────────────────────
-- Used by avgPrepTime calculation in partner dashboard.

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS confirmed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS ready_at     TIMESTAMPTZ;

-- Auto-set confirmed_at / ready_at when status changes via trigger.
CREATE OR REPLACE FUNCTION public.handle_order_status_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'confirmed' AND OLD.status != 'confirmed' THEN
    NEW.confirmed_at = now();
  END IF;
  IF NEW.status = 'ready' AND OLD.status != 'ready' THEN
    NEW.ready_at = now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS order_status_timestamps ON public.orders;
CREATE TRIGGER order_status_timestamps
  BEFORE UPDATE ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_order_status_timestamps();
