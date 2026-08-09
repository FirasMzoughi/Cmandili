-- ============================================================================
-- CMANDILI — Backfill migration: admin commissions + settlements.
--
-- This schema was applied directly via the Supabase SQL Editor around
-- 2026-05-11 (see cmandili_client/RESUME.md §5, which names this exact
-- filename as "not committed, applied manually") and was never captured as
-- a migration file. It IS already live in production — this file exists only
-- so the repo's migration history matches reality; it changes nothing when
-- run against the current database (all statements are idempotent).
--
-- Reconstructed on 2026-08-09 from the live schema via PostgREST OpenAPI
-- introspection (column names/types/defaults) plus live sample rows
-- (confirmed 3-decimal TND/millimes precision on populated orders). RLS
-- policy bodies below are NOT extracted byte-for-byte from production —
-- PostgREST does not expose pg_policies over REST — they are reconstructed
-- to match the app's established ownership patterns. Diff against the
-- Supabase dashboard's Policies tab before relying on the policy wording.
--
-- Business rules (per RESUME.md): restaurants keep 90% of subtotal (10%
-- platform commission); drivers earn a base fee + per-km, admin keeps 23%
-- of the driver fee as platform cut. `orders.platform_fee` /
-- `orders.driver_fee_cut` capture the computed cuts per order;
-- `settlements` is the payout ledger; `drivers.commission_paid` /
-- `restaurants.commission_paid` track running totals already paid out.
-- ============================================================================

-- ── 1. Per-order commission columns ─────────────────────────────────────────
-- NOTE: subtotal/delivery_fee/total already exist and are confirmed live at
-- 3-decimal (millimes) precision on real rows — not touched here. This
-- backfill only adds the two new columns; it does not attempt to alter the
-- type/precision of pre-existing columns (unverifiable safely via REST
-- introspection, and unnecessary since they're already correct in prod).
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS platform_fee    NUMERIC(12,3) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS driver_fee_cut  NUMERIC(12,3) NOT NULL DEFAULT 0;


-- ── 2. Running commission totals on partners / drivers ──────────────────────
ALTER TABLE public.partners
  ADD COLUMN IF NOT EXISTS commission_rate NUMERIC(5,2) NOT NULL DEFAULT 10.00;

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS commission_paid NUMERIC(12,3) NOT NULL DEFAULT 0;

ALTER TABLE public.drivers
  ADD COLUMN IF NOT EXISTS commission_paid NUMERIC(12,3) NOT NULL DEFAULT 0;


-- ── 3. Settlements ledger (payout records) ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.settlements (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entity_type      text        NOT NULL,               -- 'restaurant' | 'driver' | ...
  amount           NUMERIC(12,3) NOT NULL,
  type             text        NOT NULL,                -- e.g. 'payout' | 'adjustment'
  status           text        NOT NULL DEFAULT 'pending',
  description      text,
  related_order_id uuid        REFERENCES public.orders(id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  paid_at          timestamptz
);

CREATE INDEX IF NOT EXISTS settlements_user_id_created_at_idx
  ON public.settlements (user_id, created_at DESC);

ALTER TABLE public.settlements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users read own settlements" ON public.settlements;
CREATE POLICY "Users read own settlements"
  ON public.settlements FOR SELECT USING (auth.uid() = user_id);

-- Settlements are admin/service-role authored (payout runs), never written
-- directly by partner/driver clients.
DROP POLICY IF EXISTS "Service role manages settlements" ON public.settlements;
CREATE POLICY "Service role manages settlements"
  ON public.settlements FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');
