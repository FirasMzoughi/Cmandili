-- Push a notification to customers when a happy hour starts
-- ============================================================================
-- When a partner activates a happy hour (vendor_items.discount_price goes
-- from NULL to a price), call the push-happy-hour Edge Function, which sends
-- "🔥 Happy Hour chez <shop>: <item> à X DT au lieu de Y DT" to every
-- customer's phone, in their app language, via FCM topics.
--
-- Same invocation pattern as notify_fcm_on_order_status (pg_net + the app's
-- public key). Because that key is public, the function itself re-checks the
-- deal and uses happy_hour_notified_at to push at most once per item per
-- hour.
--
-- Only the START of a deal notifies. Changing the price of a running deal,
-- stopping it, or the quantity trigger ending it at zero do not.

begin;

alter table public.vendor_items
  add column if not exists happy_hour_notified_at timestamptz;

create or replace function public.notify_happy_hour_started()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text := coalesce(
    current_setting('app.happy_hour_push_url', true),
    'https://hoqlxxtphskgxktqjpfu.supabase.co/functions/v1/push-happy-hour'
  );
  v_secret text := coalesce(
    current_setting('app.edge_function_secret', true),
    'sb_publishable_wKhzJeVlKGWFe85PyGhyXg_gBJr97hK'
  );
begin
  perform net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body    := jsonb_build_object('item_id', new.id)
  );
  return new;
end;
$$;

drop trigger if exists on_happy_hour_started on public.vendor_items;
create trigger on_happy_hour_started
after update of discount_price on public.vendor_items
for each row
when (old.discount_price is null and new.discount_price is not null)
execute function public.notify_happy_hour_started();

commit;
