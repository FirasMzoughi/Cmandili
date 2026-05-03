-- ============================================================================
-- CMANDILI PARTNER — Complete Supabase SQL Setup (Idempotent)
-- Run this in Supabase Dashboard → SQL Editor → New Query → Run
-- Safe to re-run — drops existing policies before recreating them.
-- ============================================================================

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  1. PROFILES TABLE (Supabase Auth user profiles)                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name   TEXT,
  avatar_url  TEXT,
  phone       TEXT,
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Auto-create a profile row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'name'),
    COALESCE(NEW.raw_user_meta_data ->> 'avatar_url', NEW.raw_user_meta_data ->> 'picture')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  2. PARTNERS TABLE (restaurant/supermarket partner accounts)               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Partners can view own record" ON public.partners;
CREATE POLICY "Partners can view own record"
  ON public.partners FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Partners can insert own record" ON public.partners;
CREATE POLICY "Partners can insert own record"
  ON public.partners FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Partners can update own record" ON public.partners;
CREATE POLICY "Partners can update own record"
  ON public.partners FOR UPDATE
  USING (auth.uid() = user_id);


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  3. RESTAURANTS TABLE                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Anyone can read restaurants" ON public.restaurants;
CREATE POLICY "Anyone can read restaurants"
  ON public.restaurants FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated can insert restaurants" ON public.restaurants;
CREATE POLICY "Authenticated can insert restaurants"
  ON public.restaurants FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can update restaurants" ON public.restaurants;
CREATE POLICY "Authenticated can update restaurants"
  ON public.restaurants FOR UPDATE
  USING (auth.role() = 'authenticated');


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  4. FOOD_ITEMS TABLE (dishes for restaurants)                              ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Anyone can read food_items" ON public.food_items;
CREATE POLICY "Anyone can read food_items"
  ON public.food_items FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated can insert food_items" ON public.food_items;
CREATE POLICY "Authenticated can insert food_items"
  ON public.food_items FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can update food_items" ON public.food_items;
CREATE POLICY "Authenticated can update food_items"
  ON public.food_items FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can delete food_items" ON public.food_items;
CREATE POLICY "Authenticated can delete food_items"
  ON public.food_items FOR DELETE
  USING (auth.role() = 'authenticated');


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  5. SUPERMARKETS TABLE                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Anyone can read supermarkets" ON public.supermarkets;
CREATE POLICY "Anyone can read supermarkets"
  ON public.supermarkets FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated can insert supermarkets" ON public.supermarkets;
CREATE POLICY "Authenticated can insert supermarkets"
  ON public.supermarkets FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can update supermarkets" ON public.supermarkets;
CREATE POLICY "Authenticated can update supermarkets"
  ON public.supermarkets FOR UPDATE
  USING (auth.role() = 'authenticated');


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  6. GROCERY_ITEMS TABLE (products for supermarkets)                        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Anyone can read grocery_items" ON public.grocery_items;
CREATE POLICY "Anyone can read grocery_items"
  ON public.grocery_items FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated can insert grocery_items" ON public.grocery_items;
CREATE POLICY "Authenticated can insert grocery_items"
  ON public.grocery_items FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can update grocery_items" ON public.grocery_items;
CREATE POLICY "Authenticated can update grocery_items"
  ON public.grocery_items FOR UPDATE
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated can delete grocery_items" ON public.grocery_items;
CREATE POLICY "Authenticated can delete grocery_items"
  ON public.grocery_items FOR DELETE
  USING (auth.role() = 'authenticated');


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  7. ORDERS TABLE                                                           ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.orders (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id           UUID REFERENCES public.restaurants(id),
  supermarket_id          UUID REFERENCES public.supermarkets(id),
  status                  TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'ready', 'pickedUp', 'onTheWay', 'delivered', 'cancelled')),
  subtotal                DOUBLE PRECISION NOT NULL DEFAULT 0,
  delivery_fee            DOUBLE PRECISION DEFAULT 0,
  total                   DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_method          TEXT DEFAULT 'cash',
  notes                   TEXT,
  delivery_address        JSONB DEFAULT '{}'::jsonb,
  order_type              TEXT DEFAULT 'food',
  estimated_delivery_time TIMESTAMPTZ,
  driver_id               UUID,
  pickup_address          JSONB,
  recipient_name          TEXT,
  recipient_phone         TEXT,
  package_description     TEXT,
  created_at              TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_user      ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_restaurant ON public.orders(restaurant_id);
CREATE INDEX IF NOT EXISTS idx_orders_supermarket ON public.orders(supermarket_id);
CREATE INDEX IF NOT EXISTS idx_orders_status     ON public.orders(status);

ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own orders" ON public.orders;
CREATE POLICY "Users can read own orders"
  ON public.orders FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Partners can read their orders" ON public.orders;
CREATE POLICY "Partners can read their orders"
  ON public.orders FOR SELECT
  USING (
    restaurant_id IN (SELECT entity_id::uuid FROM public.partners WHERE user_id = auth.uid() AND partner_type = 'restaurant' AND entity_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') OR
    supermarket_id IN (SELECT entity_id::uuid FROM public.partners WHERE user_id = auth.uid() AND partner_type = 'supermarket' AND entity_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
  );

DROP POLICY IF EXISTS "Authenticated can insert orders" ON public.orders;
CREATE POLICY "Authenticated can insert orders"
  ON public.orders FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated can update orders" ON public.orders;
CREATE POLICY "Authenticated can update orders"
  ON public.orders FOR UPDATE
  USING (auth.role() = 'authenticated');

-- Enable realtime for orders (so stream works)
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  7b. DRIVERS TABLE                                                         ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.drivers (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_online            BOOLEAN DEFAULT false,
  current_lat          DOUBLE PRECISION,
  current_lng          DOUBLE PRECISION,
  last_location_update TIMESTAMPTZ,
  created_at           TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id)
);

CREATE INDEX IF NOT EXISTS idx_drivers_user ON public.drivers(user_id);

ALTER TABLE public.drivers ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Drivers can manage own record" ON public.drivers;
CREATE POLICY "Drivers can manage own record"
  ON public.drivers
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Anyone can read driver location" ON public.drivers;
CREATE POLICY "Anyone can read driver location"
  ON public.drivers FOR SELECT
  USING (auth.role() = 'authenticated');

-- Enable realtime so customers receive live driver position
ALTER PUBLICATION supabase_realtime ADD TABLE public.drivers;


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  7c. DELIVERIES TABLE                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Authenticated can read deliveries" ON public.deliveries;
CREATE POLICY "Authenticated can read deliveries"
  ON public.deliveries FOR SELECT
  USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Drivers can manage deliveries" ON public.deliveries;
CREATE POLICY "Drivers can manage deliveries"
  ON public.deliveries FOR ALL
  USING (auth.role() = 'authenticated')
  WITH CHECK (auth.role() = 'authenticated');

-- Enable realtime so customers receive live driver position via deliveries stream
ALTER PUBLICATION supabase_realtime ADD TABLE public.deliveries;


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  7d. PAYMENTS TABLE                                                        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id),
  amount          DOUBLE PRECISION NOT NULL,
  method          TEXT NOT NULL,        -- 'cash'
  status          TEXT DEFAULT 'pending', -- pending, paid, failed, refunded
  gateway_ref     TEXT,                 -- payment gateway transaction ID
  gateway_payload JSONB,                -- raw gateway response for audit
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments_order ON public.payments(order_id);
CREATE INDEX IF NOT EXISTS idx_payments_user  ON public.payments(user_id);

ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own payments" ON public.payments;
CREATE POLICY "Users can read own payments"
  ON public.payments FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated can insert payments" ON public.payments;
CREATE POLICY "Authenticated can insert payments"
  ON public.payments FOR INSERT
  WITH CHECK (auth.uid() = user_id);


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  8. ORDER_ITEMS TABLE                                                      ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.order_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id        UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  food_item_id    UUID REFERENCES public.food_items(id),
  grocery_item_id UUID REFERENCES public.grocery_items(id),
  quantity             INTEGER NOT NULL DEFAULT 1,
  price                DOUBLE PRECISION NOT NULL DEFAULT 0,
  special_instructions TEXT,
  options              JSONB DEFAULT '{}'::jsonb,
  created_at           TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON public.order_items(order_id);

ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own order items" ON public.order_items;
CREATE POLICY "Users can read own order items"
  ON public.order_items FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Authenticated can insert order items" ON public.order_items;
CREATE POLICY "Authenticated can insert order items"
  ON public.order_items FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  9. NOTIFICATIONS TABLE                                                    ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
  ON public.notifications FOR DELETE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "System can insert notifications" ON public.notifications;
CREATE POLICY "System can insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  9b. NOTIFICATIONS TRIGGER                                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  10. USER ADDRESSES TABLE                                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

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

DROP POLICY IF EXISTS "Users can manage own addresses" ON public.user_addresses;
CREATE POLICY "Users can manage own addresses"
  ON public.user_addresses
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  11. SUPPORT TICKETS TABLE                                                 ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.support_tickets (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  subject    TEXT NOT NULL,
  message    TEXT NOT NULL,
  status     TEXT DEFAULT 'open',
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can insert own tickets" ON public.support_tickets;
CREATE POLICY "Users can insert own tickets"
  ON public.support_tickets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can read own tickets" ON public.support_tickets;
CREATE POLICY "Users can read own tickets"
  ON public.support_tickets FOR SELECT
  USING (auth.uid() = user_id);


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  12. STORAGE BUCKETS                                                       ║
-- ║  Create these in Supabase Dashboard → Storage → New Bucket                 ║
-- ║  OR run the SQL below.                                                     ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Bucket: items (for food/grocery item images)
INSERT INTO storage.buckets (id, name, public) VALUES ('items', 'items', true)
  ON CONFLICT (id) DO NOTHING;

-- Bucket: profiles (for partner avatar images)
INSERT INTO storage.buckets (id, name, public) VALUES ('profiles', 'profiles', true)
  ON CONFLICT (id) DO NOTHING;

-- Bucket: menu-images (legacy, used in supabase_service.dart)
INSERT INTO storage.buckets (id, name, public) VALUES ('menu-images', 'menu-images', true)
  ON CONFLICT (id) DO NOTHING;

-- Storage RLS: allow authenticated users to upload
DROP POLICY IF EXISTS "Authenticated users can upload items" ON storage.objects;
CREATE POLICY "Authenticated users can upload items"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id IN ('items', 'profiles', 'menu-images') AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Authenticated users can update items" ON storage.objects;
CREATE POLICY "Authenticated users can update items"
  ON storage.objects FOR UPDATE
  USING (bucket_id IN ('items', 'profiles', 'menu-images') AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Anyone can view public bucket files" ON storage.objects;
CREATE POLICY "Anyone can view public bucket files"
  ON storage.objects FOR SELECT
  USING (bucket_id IN ('items', 'profiles', 'menu-images'));


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  13. USER_FAVORITES TABLE                                                  ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

CREATE TABLE IF NOT EXISTS public.user_favorites (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  restaurant_id UUID NOT NULL REFERENCES public.restaurants(id) ON DELETE CASCADE,
  created_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, restaurant_id)
);

CREATE INDEX IF NOT EXISTS idx_user_favorites_user ON public.user_favorites(user_id);

ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own favorites" ON public.user_favorites;
CREATE POLICY "Users can manage own favorites"
  ON public.user_favorites
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  14. GET_DRIVER_EARNINGS RPC                                               ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝

-- Returns total earnings and delivery count for a driver within a date range.
-- Called by the driver earnings screen.
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
  v_total  DOUBLE PRECISION;
  v_count  INTEGER;
BEGIN
  SELECT
    COALESCE(SUM(o.delivery_fee), 0),
    COUNT(*)
  INTO v_total, v_count
  FROM public.orders o
  JOIN public.drivers d ON d.id = p_driver_id
  WHERE o.driver_id = d.id
    AND o.status = 'delivered'
    AND o.created_at >= p_start_date
    AND o.created_at <= p_end_date;

  RETURN json_build_object('total', v_total, 'count', v_count);
END;
$$;


-- ╔══════════════════════════════════════════════════════════════════════════════╗
-- ║  DONE! Your Supabase is ready for cmandili_partner.                        ║
-- ╚══════════════════════════════════════════════════════════════════════════════╝
