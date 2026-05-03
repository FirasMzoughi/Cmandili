-- ============================================================================
-- CMANDILI — Master schema. Single idempotent file for all three apps.
-- Run once in Supabase SQL Editor. Safe to re-run at any time.
-- Order: auth-dependent tables first, then relations, then triggers/functions.
-- ============================================================================


-- ── 1. profiles ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.profiles (
  id         UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name  TEXT,
  avatar_url TEXT,
  phone      TEXT,
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
CREATE POLICY "profiles_select" ON public.profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_insert" ON public.profiles;
CREATE POLICY "profiles_insert" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "profiles_update" ON public.profiles;
CREATE POLICY "profiles_update" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Auto-create profile on sign-up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name'),
    COALESCE(NEW.raw_user_meta_data ->> 'avatar_url', NEW.raw_user_meta_data ->> 'picture')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ── 2. partners ───────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.partners (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  partner_type  TEXT NOT NULL CHECK (partner_type IN ('restaurant', 'supermarket')),
  business_name TEXT NOT NULL DEFAULT '',
  entity_id     TEXT NOT NULL DEFAULT '',
  address       TEXT DEFAULT '',
  phone         TEXT DEFAULT '',
  bio           TEXT DEFAULT '',
  avatar_url    TEXT DEFAULT '',
  created_at    TIMESTAMPTZ DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_partners_user_id ON public.partners(user_id);

ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "partners_select" ON public.partners;
CREATE POLICY "partners_select" ON public.partners FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "partners_insert" ON public.partners;
CREATE POLICY "partners_insert" ON public.partners FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "partners_update" ON public.partners;
CREATE POLICY "partners_update" ON public.partners FOR UPDATE USING (auth.uid() = user_id);


-- ── 3. restaurants ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.restaurants (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL DEFAULT '',
  description       TEXT DEFAULT '',
  image_url         TEXT DEFAULT '',
  rating            DOUBLE PRECISION DEFAULT 0,
  review_count      INTEGER DEFAULT 0,
  categories        TEXT[] DEFAULT '{}',
  delivery_time_min INTEGER DEFAULT 30,
  delivery_fee      DOUBLE PRECISION DEFAULT 0,
  min_order         DOUBLE PRECISION DEFAULT 0,
  is_open           BOOLEAN DEFAULT true,
  latitude          DOUBLE PRECISION DEFAULT 0,
  longitude         DOUBLE PRECISION DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.restaurants ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "restaurants_select" ON public.restaurants;
CREATE POLICY "restaurants_select" ON public.restaurants FOR SELECT USING (true);

DROP POLICY IF EXISTS "restaurants_insert" ON public.restaurants;
CREATE POLICY "restaurants_insert" ON public.restaurants FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "restaurants_update" ON public.restaurants;
CREATE POLICY "restaurants_update" ON public.restaurants FOR UPDATE USING (auth.role() = 'authenticated');


-- ── 4. food_items ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.food_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  restaurant_id     UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  name              TEXT NOT NULL DEFAULT '',
  description       TEXT DEFAULT '',
  image_url         TEXT DEFAULT '',
  price             DOUBLE PRECISION NOT NULL DEFAULT 0,
  category          TEXT DEFAULT '',
  is_available      BOOLEAN DEFAULT true,
  preparation_time  INTEGER DEFAULT 15,
  is_vegetarian     BOOLEAN DEFAULT false,
  is_spicy          BOOLEAN DEFAULT false,
  discount_price    DOUBLE PRECISION,
  discount_end_time TIMESTAMPTZ,
  discount_quantity INTEGER,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_food_items_restaurant ON public.food_items(restaurant_id);

ALTER TABLE public.food_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "food_items_select" ON public.food_items;
CREATE POLICY "food_items_select" ON public.food_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "food_items_insert" ON public.food_items;
CREATE POLICY "food_items_insert" ON public.food_items FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "food_items_update" ON public.food_items;
CREATE POLICY "food_items_update" ON public.food_items FOR UPDATE USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "food_items_delete" ON public.food_items;
CREATE POLICY "food_items_delete" ON public.food_items FOR DELETE USING (auth.role() = 'authenticated');


-- ── 5. supermarkets ───────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.supermarkets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name              TEXT NOT NULL DEFAULT '',
  description       TEXT DEFAULT '',
  image_url         TEXT DEFAULT '',
  rating            DOUBLE PRECISION DEFAULT 0,
  review_count      INTEGER DEFAULT 0,
  delivery_time_min INTEGER DEFAULT 30,
  delivery_fee      DOUBLE PRECISION DEFAULT 0,
  min_order         DOUBLE PRECISION DEFAULT 0,
  is_open           BOOLEAN DEFAULT true,
  latitude          DOUBLE PRECISION DEFAULT 0,
  longitude         DOUBLE PRECISION DEFAULT 0,
  created_at        TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.supermarkets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "supermarkets_select" ON public.supermarkets;
CREATE POLICY "supermarkets_select" ON public.supermarkets FOR SELECT USING (true);

DROP POLICY IF EXISTS "supermarkets_insert" ON public.supermarkets;
CREATE POLICY "supermarkets_insert" ON public.supermarkets FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "supermarkets_update" ON public.supermarkets;
CREATE POLICY "supermarkets_update" ON public.supermarkets FOR UPDATE USING (auth.role() = 'authenticated');


-- ── 6. grocery_items ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.grocery_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supermarket_id    UUID NOT NULL REFERENCES public.supermarkets(id) ON DELETE CASCADE,
  name              TEXT NOT NULL DEFAULT '',
  description       TEXT DEFAULT '',
  image_url         TEXT DEFAULT '',
  price             DOUBLE PRECISION NOT NULL DEFAULT 0,
  category          TEXT DEFAULT '',
  unit              TEXT DEFAULT 'piece',
  is_organic        BOOLEAN DEFAULT false,
  is_available      BOOLEAN DEFAULT true,
  discount_price    DOUBLE PRECISION,
  discount_end_time TIMESTAMPTZ,
  discount_quantity INTEGER,
  created_at        TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_grocery_items_supermarket ON public.grocery_items(supermarket_id);

ALTER TABLE public.grocery_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "grocery_items_select" ON public.grocery_items;
CREATE POLICY "grocery_items_select" ON public.grocery_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "grocery_items_insert" ON public.grocery_items;
CREATE POLICY "grocery_items_insert" ON public.grocery_items FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "grocery_items_update" ON public.grocery_items;
CREATE POLICY "grocery_items_update" ON public.grocery_items FOR UPDATE USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "grocery_items_delete" ON public.grocery_items;
CREATE POLICY "grocery_items_delete" ON public.grocery_items FOR DELETE USING (auth.role() = 'authenticated');


-- ── 7. drivers ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.drivers (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_online            BOOLEAN NOT NULL DEFAULT false,
  current_lat          DOUBLE PRECISION,
  current_lng          DOUBLE PRECISION,
  last_location_update TIMESTAMPTZ,
  vehicle_type         TEXT,
  vehicle_make         TEXT,
  vehicle_model        TEXT,
  vehicle_plate        TEXT,
  vehicle_color        TEXT,
  created_at           TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_drivers_user ON public.drivers(user_id);

ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "drivers_own_rw" ON public.drivers;
CREATE POLICY "drivers_own_rw"
  ON public.drivers
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "drivers_location_read" ON public.drivers;
CREATE POLICY "drivers_location_read"
  ON public.drivers FOR SELECT
  USING (auth.role() = 'authenticated');

ALTER PUBLICATION supabase_realtime ADD TABLE public.drivers;


-- ── 8. orders ─────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.orders (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id           UUID REFERENCES public.restaurants(id),
  supermarket_id          UUID REFERENCES public.supermarkets(id),
  driver_id               UUID,
  status                  TEXT NOT NULL DEFAULT 'pending'
                            CHECK (status IN ('pending','confirmed','preparing','ready','pickedUp','onTheWay','delivered','cancelled')),
  subtotal                DOUBLE PRECISION NOT NULL DEFAULT 0,
  delivery_fee            DOUBLE PRECISION DEFAULT 0,
  total                   DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_method          TEXT DEFAULT 'cash',
  notes                   TEXT,
  delivery_address        JSONB DEFAULT '{}'::jsonb,
  order_type              TEXT DEFAULT 'food',
  estimated_delivery_time TIMESTAMPTZ,
  pickup_address          JSONB,
  recipient_name          TEXT,
  recipient_phone         TEXT,
  package_description     TEXT,
  confirmed_at            TIMESTAMPTZ,
  ready_at                TIMESTAMPTZ,
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_user        ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant  ON public.orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_supermarket ON public.orders(supermarket_id);
CREATE INDEX IF NOT EXISTS idx_orders_status      ON public.orders(status);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_user_select" ON public.orders;
CREATE POLICY "orders_user_select"
  ON public.orders FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "orders_partner_select" ON public.orders;
CREATE POLICY "orders_partner_select"
  ON public.orders FOR SELECT
  USING (
    restaurant_id  IN (SELECT entity_id::uuid FROM public.partners WHERE user_id = auth.uid() AND partner_type = 'restaurant'  AND entity_id ~ '^[0-9a-f-]{36}$') OR
    supermarket_id IN (SELECT entity_id::uuid FROM public.partners WHERE user_id = auth.uid() AND partner_type = 'supermarket' AND entity_id ~ '^[0-9a-f-]{36}$')
  );

DROP POLICY IF EXISTS "orders_driver_select" ON public.orders;
CREATE POLICY "orders_driver_select"
  ON public.orders FOR SELECT
  USING (
    driver_id IN (SELECT id FROM public.drivers WHERE user_id = auth.uid()) OR
    status IN ('pending','ready')
  );

DROP POLICY IF EXISTS "orders_insert" ON public.orders;
CREATE POLICY "orders_insert"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "orders_update" ON public.orders;
CREATE POLICY "orders_update"
  ON public.orders FOR UPDATE
  USING (auth.role() = 'authenticated');

ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;

-- Auto-stamp confirmed_at / ready_at
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


-- ── 9. order_items ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.order_items (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id             UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  food_item_id         UUID REFERENCES public.food_items(id),
  grocery_item_id      UUID REFERENCES public.grocery_items(id),
  quantity             INTEGER NOT NULL DEFAULT 1,
  price                DOUBLE PRECISION NOT NULL DEFAULT 0,
  special_instructions TEXT,
  options              JSONB DEFAULT '{}'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_items_select" ON public.order_items;
CREATE POLICY "order_items_select" ON public.order_items FOR SELECT USING (true);

DROP POLICY IF EXISTS "order_items_insert" ON public.order_items;
CREATE POLICY "order_items_insert" ON public.order_items FOR INSERT WITH CHECK (auth.role() = 'authenticated');


-- ── 10. deliveries ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.deliveries (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id    UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  driver_id   UUID NOT NULL REFERENCES public.drivers(id),
  status      TEXT DEFAULT 'accepted',
  current_lat DOUBLE PRECISION DEFAULT 0,
  current_lng DOUBLE PRECISION DEFAULT 0,
  updated_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deliveries_order  ON public.deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_driver ON public.deliveries(driver_id);

ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "deliveries_select" ON public.deliveries;
CREATE POLICY "deliveries_select"
  ON public.deliveries FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "deliveries_rw" ON public.deliveries;
CREATE POLICY "deliveries_rw"
  ON public.deliveries FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;


-- ── 11. payments ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id),
  amount          DOUBLE PRECISION NOT NULL,
  method          TEXT NOT NULL,       -- cash
  status          TEXT DEFAULT 'pending',  -- pending | paid | failed | refunded
  gateway_ref     TEXT,                -- payment gateway transaction ID
  gateway_payload JSONB,               -- raw gateway response for audit
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user  ON public.payments(user_id);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payments_select" ON public.payments;
CREATE POLICY "payments_select" ON public.payments FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "payments_insert" ON public.payments;
CREATE POLICY "payments_insert" ON public.payments FOR INSERT WITH CHECK (auth.uid() = user_id);


-- ── 12. notifications ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.notifications (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title      TEXT DEFAULT '',
  message    TEXT DEFAULT '',
  type       TEXT DEFAULT 'general',
  data       JSONB DEFAULT '{}'::jsonb,
  is_read    BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notifications_select" ON public.notifications;
CREATE POLICY "notifications_select" ON public.notifications FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_update" ON public.notifications;
CREATE POLICY "notifications_update" ON public.notifications FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_delete" ON public.notifications;
CREATE POLICY "notifications_delete" ON public.notifications FOR DELETE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "notifications_insert" ON public.notifications;
CREATE POLICY "notifications_insert" ON public.notifications FOR INSERT WITH CHECK (true);

-- In-app notification on every order status change
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status != OLD.status THEN
    INSERT INTO public.notifications (user_id, title, message, type, data)
    VALUES (
      NEW.user_id,
      'Order Status Update',
      'Your order #' || UPPER(SUBSTRING(NEW.id::text, 1, 8)) || ' is now ' || NEW.status,
      'order_status',
      jsonb_build_object('order_id', NEW.id, 'status', NEW.status)
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_order_status_changed ON public.orders;
CREATE TRIGGER on_order_status_changed
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.handle_order_status_change();


-- ── 13. reviews ───────────────────────────────────────────────────────────────

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
  ON public.reviews(user_id, order_id) WHERE order_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS reviews_entity_idx ON public.reviews(entity_id);

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "reviews_insert" ON public.reviews;
CREATE POLICY "reviews_insert" ON public.reviews FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "reviews_select" ON public.reviews;
CREATE POLICY "reviews_select" ON public.reviews FOR SELECT USING (true);

DROP POLICY IF EXISTS "reviews_delete_own" ON public.reviews;
CREATE POLICY "reviews_delete_own" ON public.reviews FOR DELETE USING (auth.uid() = user_id);


-- ── 14. user_addresses ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_addresses (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  full_address TEXT NOT NULL,
  is_default   BOOLEAN DEFAULT false,
  latitude     DOUBLE PRECISION DEFAULT 0,
  longitude    DOUBLE PRECISION DEFAULT 0,
  created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON public.user_addresses(user_id);

ALTER TABLE public.user_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_addresses_rw" ON public.user_addresses;
CREATE POLICY "user_addresses_rw"
  ON public.user_addresses
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ── 15. user_favorites ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.user_favorites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, restaurant_id)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user ON public.user_favorites(user_id);

ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "user_favorites_rw" ON public.user_favorites;
CREATE POLICY "user_favorites_rw"
  ON public.user_favorites
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ── 16. payment_methods ───────────────────────────────────────────────────────
-- Tokenised card references — never store full PAN.

CREATE TABLE IF NOT EXISTS public.payment_methods (
  id               UUID PRIMARY KEY,
  user_id          UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  card_holder_name TEXT NOT NULL,
  last_four        TEXT NOT NULL,
  expiry_date      TEXT NOT NULL,
  is_default       BOOLEAN NOT NULL DEFAULT false,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_methods_user ON public.payment_methods(user_id);

ALTER TABLE public.payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "payment_methods_select" ON public.payment_methods;
CREATE POLICY "payment_methods_select" ON public.payment_methods FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "payment_methods_insert" ON public.payment_methods;
CREATE POLICY "payment_methods_insert" ON public.payment_methods FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "payment_methods_update" ON public.payment_methods;
CREATE POLICY "payment_methods_update" ON public.payment_methods FOR UPDATE USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "payment_methods_delete" ON public.payment_methods;
CREATE POLICY "payment_methods_delete" ON public.payment_methods FOR DELETE USING (auth.uid() = user_id);


-- ── 17. partner_payout_info ───────────────────────────────────────────────────

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


-- ── 18. driver_payout_info ────────────────────────────────────────────────────

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


-- ── 19. device_tokens ─────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.device_tokens (
  token      TEXT PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  platform   TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "device_tokens_rw" ON public.device_tokens;
CREATE POLICY "device_tokens_rw"
  ON public.device_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ── 20. support_tickets ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  subject    TEXT NOT NULL,
  message    TEXT NOT NULL,
  status     TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "support_tickets_insert" ON public.support_tickets;
CREATE POLICY "support_tickets_insert" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "support_tickets_select" ON public.support_tickets;
CREATE POLICY "support_tickets_select" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id);


-- ── 21. storage buckets ───────────────────────────────────────────────────────

INSERT INTO storage.buckets (id, name, public) VALUES ('items',       'items',       true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('profiles',    'profiles',    true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('menu-images', 'menu-images', true) ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "storage_upload"  ON storage.objects;
CREATE POLICY "storage_upload"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id IN ('items','profiles','menu-images') AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "storage_update"  ON storage.objects;
CREATE POLICY "storage_update"
  ON storage.objects FOR UPDATE
  USING (bucket_id IN ('items','profiles','menu-images') AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "storage_select"  ON storage.objects;
CREATE POLICY "storage_select"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('items','profiles','menu-images'));


-- ── 22. get_driver_earnings RPC ───────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.get_driver_earnings(
  p_driver_id  UUID,
  p_start_date TIMESTAMPTZ,
  p_end_date   TIMESTAMPTZ
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total DOUBLE PRECISION;
  v_count INTEGER;
BEGIN
  SELECT
    COALESCE(SUM(o.delivery_fee), 0),
    COUNT(*)
  INTO v_total, v_count
  FROM public.orders o
  WHERE o.driver_id = p_driver_id
    AND o.status = 'delivered'
    AND o.created_at >= p_start_date
    AND o.created_at <= p_end_date;

  RETURN json_build_object('total', v_total, 'count', v_count);
END;
$$;


-- ── 23. FCM push via Edge Function ───────────────────────────────────────────
-- Requires the pg_net extension (enabled by default on Supabase).
-- Set EDGE_FUNCTION_URL to your project's Edge Function URL, e.g.:
--   https://<project-ref>.supabase.co/functions/v1/push-on-order-status
-- Set EDGE_FUNCTION_SECRET to your Supabase anon key (sent as Authorization header).
--
-- After running this file, also set these in Supabase Dashboard:
--   SQL Editor → run:
--     ALTER DATABASE postgres SET app.edge_function_url = 'https://...';
--     ALTER DATABASE postgres SET app.edge_function_secret = 'your-anon-key';

CREATE OR REPLACE FUNCTION public.notify_fcm_on_order_status()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := current_setting('app.edge_function_url',  true);
  v_secret TEXT := current_setting('app.edge_function_secret', true);
BEGIN
  IF NEW.status != OLD.status AND v_url IS NOT NULL AND v_url != '' THEN
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


-- ── Done ──────────────────────────────────────────────────────────────────────
-- Run this file once. All statements are idempotent (IF NOT EXISTS / OR REPLACE).
-- Old separate files (supabase_setup.sql, supabase_migrations.sql,
-- supabase_phase2_3.sql) are superseded by this file.
