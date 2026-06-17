-- ============================================================================
-- CMANDILI — Item variants + per-item voice notes.
--
-- Adds three things:
--
--   1. `food_item_variants` — list of named variants per food item, each with
--      its own price (e.g. "Chocolate cake 8DT", "Vanilla cake 7DT"). Variants
--      are optional: items with no rows here keep using `food_items.price`.
--
--   2. `grocery_item_variants` — same structure for grocery items.
--
--   3. `order_items.voice_note_url` — public Supabase Storage URL of an AAC
--      voice clip the customer attached to a specific cart line. Per-item
--      (one note per dish), not per-order. Null when no voice note.
--
-- All idempotent — safe to re-run.
-- ============================================================================

-- ── 1. food_item_variants ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.food_item_variants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  food_item_id  UUID NOT NULL REFERENCES public.food_items(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  price         DOUBLE PRECISION NOT NULL CHECK (price >= 0),
  is_available  BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order    INTEGER NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_item_variants_item
  ON public.food_item_variants(food_item_id, sort_order);

ALTER TABLE public.food_item_variants ENABLE ROW LEVEL SECURITY;

-- Public read so the customer app can list variants of any restaurant's items.
DROP POLICY IF EXISTS food_item_variants_public_read ON public.food_item_variants;
CREATE POLICY food_item_variants_public_read
  ON public.food_item_variants FOR SELECT
  USING (TRUE);

-- Restaurant partners can insert/update/delete only variants of their own items.
-- Linkage: partners.user_id = auth.uid() AND partners.entity_id::uuid = restaurants.id.
DROP POLICY IF EXISTS food_item_variants_owner_write ON public.food_item_variants;
CREATE POLICY food_item_variants_owner_write
  ON public.food_item_variants FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.food_items fi
      WHERE fi.id = food_item_variants.food_item_id
        AND fi.restaurant_id IN (
          SELECT entity_id::uuid FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
            AND entity_id ~ '^[0-9a-f-]{36}$'
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.food_items fi
      WHERE fi.id = food_item_variants.food_item_id
        AND fi.restaurant_id IN (
          SELECT entity_id::uuid FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'restaurant'
            AND entity_id ~ '^[0-9a-f-]{36}$'
        )
    )
  );

-- ── 2. grocery_item_variants ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.grocery_item_variants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grocery_item_id UUID NOT NULL REFERENCES public.grocery_items(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  price           DOUBLE PRECISION NOT NULL CHECK (price >= 0),
  is_available    BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_grocery_item_variants_item
  ON public.grocery_item_variants(grocery_item_id, sort_order);

ALTER TABLE public.grocery_item_variants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS grocery_item_variants_public_read ON public.grocery_item_variants;
CREATE POLICY grocery_item_variants_public_read
  ON public.grocery_item_variants FOR SELECT
  USING (TRUE);

DROP POLICY IF EXISTS grocery_item_variants_owner_write ON public.grocery_item_variants;
CREATE POLICY grocery_item_variants_owner_write
  ON public.grocery_item_variants FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.grocery_items gi
      WHERE gi.id = grocery_item_variants.grocery_item_id
        AND gi.supermarket_id IN (
          SELECT entity_id::uuid FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'supermarket'
            AND entity_id ~ '^[0-9a-f-]{36}$'
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.grocery_items gi
      WHERE gi.id = grocery_item_variants.grocery_item_id
        AND gi.supermarket_id IN (
          SELECT entity_id::uuid FROM public.partners
          WHERE user_id = auth.uid()
            AND partner_type = 'supermarket'
            AND entity_id ~ '^[0-9a-f-]{36}$'
        )
    )
  );

-- ── 3. voice_note_url on order_items ───────────────────────────────────────
ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS voice_note_url TEXT;

-- ── 4. voice-messages storage bucket (public) ──────────────────────────────
-- Customer voice clips uploaded at checkout; public so partner app can play
-- without an extra signed-URL roundtrip.
INSERT INTO storage.buckets (id, name, public)
  VALUES ('voice-messages', 'voice-messages', TRUE)
  ON CONFLICT (id) DO NOTHING;

-- Authenticated users can upload to voice-messages (their own order's clip).
DROP POLICY IF EXISTS voice_messages_upload ON storage.objects;
CREATE POLICY voice_messages_upload
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'voice-messages');

-- Anyone can read (matches public bucket).
DROP POLICY IF EXISTS voice_messages_read ON storage.objects;
CREATE POLICY voice_messages_read
  ON storage.objects FOR SELECT
  USING (bucket_id = 'voice-messages');
