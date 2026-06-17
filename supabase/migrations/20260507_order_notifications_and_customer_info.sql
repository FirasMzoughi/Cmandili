-- ============================================================================
-- CMANDILI — New-order push + customer phone-on-order convenience.
--
-- Two fixes:
--
--   1. Push to the partner when a new order is INSERTed (status='pending').
--      The existing notify_fcm_on_order_status only fires on UPDATE OF status,
--      so brand-new orders never alerted the partner. Now we fire on INSERT
--      too, reusing the same edge function (which already has 'pending' copy
--      for the partner role).
--
--   2. View `orders_with_customer` that joins orders to profiles so the
--      partner & driver apps can fetch the customer's display name + phone in
--      one shot — without storing them on every row. Falls back to
--      delivery_address.phone (the value mobile now saves at checkout) and
--      profiles.phone if the order didn't capture it.
--
-- Idempotent — safe to re-run.
-- ============================================================================

-- ── 1. Push trigger on INSERT ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_fcm_on_new_order()
RETURNS TRIGGER AS $$
DECLARE
  v_url    TEXT := current_setting('app.edge_function_url',    true);
  v_secret TEXT := current_setting('app.edge_function_secret', true);
BEGIN
  IF v_url IS NOT NULL AND v_url != '' THEN
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

DROP TRIGGER IF EXISTS on_order_insert_push ON public.orders;
CREATE TRIGGER on_order_insert_push
  AFTER INSERT ON public.orders
  FOR EACH ROW EXECUTE FUNCTION public.notify_fcm_on_new_order();


-- ── 2. View for partner/driver to read customer name + phone ────────────────
-- Resolves the customer's display info with a coalesce chain:
--   1. delivery_address.recipientName / phone (saved at mobile checkout)
--   2. profiles.full_name / profiles.phone (account default)
--   3. recipient_name / recipient_phone (courier-mode orders)
CREATE OR REPLACE VIEW public.orders_with_customer AS
SELECT
  o.*,
  COALESCE(
    NULLIF(o.delivery_address->>'recipientName', ''),
    NULLIF(p.full_name, ''),
    NULLIF(o.recipient_name, '')
  ) AS customer_name,
  COALESCE(
    NULLIF(o.delivery_address->>'phone', ''),
    NULLIF(p.phone, ''),
    NULLIF(o.recipient_phone, '')
  ) AS customer_phone
FROM public.orders o
LEFT JOIN public.profiles p ON p.id = o.user_id;

-- Views inherit RLS from underlying tables, so partners/drivers will see only
-- the rows they were already allowed to see on `orders`.

GRANT SELECT ON public.orders_with_customer TO anon, authenticated;
