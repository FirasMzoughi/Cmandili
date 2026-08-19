-- ============================================================================
-- CMANDILI — Add driver name/phone/live-location to orders_with_customer.
--
-- Bug: cmandili_partner's order-tracking map never rendered. The view this
-- app reads (orders_with_customer, from 20260507_order_notifications_and_
-- customer_info.sql) never exposed driver info, so
-- PartnerOrderRepository._mapOrderFromDb hardcoded driverName/driverPhone/
-- driverLatitude/driverLongitude to null on every read. The map widget in
-- order_tracking_screen.dart gates on driverLatitude != null, so it was
-- permanently dead — the partner never saw the driver's live position.
--
-- Fix: extend the view with a LEFT JOIN on drivers (for current_lat/lng) and
-- drivers' own profiles row (for name/phone), matching the customer_name/
-- customer_phone pattern already in this view. Idempotent — safe to re-run.
-- ============================================================================

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
  ) AS customer_phone,
  dp.full_name AS driver_name,
  dp.phone     AS driver_phone,
  d.current_lat AS driver_latitude,
  d.current_lng AS driver_longitude
FROM public.orders o
LEFT JOIN public.profiles p  ON p.id = o.user_id
LEFT JOIN public.drivers   d ON d.id = o.driver_id
LEFT JOIN public.profiles dp ON dp.id = d.user_id;

-- Views inherit RLS from underlying tables, so partners/drivers will see only
-- the rows they were already allowed to see on `orders`.

GRANT SELECT ON public.orders_with_customer TO anon, authenticated;
