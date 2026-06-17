-- ============================================================================
-- CMANDILI — Repair notifications table.
--
-- The handle_order_status_change trigger inserts into notifications(message,
-- ...). On the live DB the `message` column was missing, so every order status
-- UPDATE rolled back with:
--
--   PostgrestException: column "message" of relation "notifications"
--   does not exist (42703)
--
-- This migration brings the live table back in sync with cmandili_schema.sql
-- §12. Idempotent — safe to re-run.
-- ============================================================================

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS title   TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS message TEXT DEFAULT '',
  ADD COLUMN IF NOT EXISTS type    TEXT DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS data    JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS is_read BOOLEAN DEFAULT false;

-- Re-create the trigger function defensively, in case the live DB has an
-- older definition.
CREATE OR REPLACE FUNCTION public.handle_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IS DISTINCT FROM OLD.status THEN
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
