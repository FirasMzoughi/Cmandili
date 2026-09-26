-- Let customers rate orders from every shop category
-- ============================================================================
-- order_ratings was created when every rateable order came from a restaurant:
--
--   restaurant_id UUID NOT NULL REFERENCES public.restaurants(id)
--
-- That FK now points at restaurants_legacy, which only holds the original
-- restaurants. Checkout writes a florist / pet / gift / bakery order's vendor
-- id into orders.restaurant_id (see 20260923010000_orders_fk_to_vendors.sql,
-- which repointed the ORDERS FKs but left this one behind), so rating such an
-- order fails with 23503 and the client shows "Impossible d'envoyer votre
-- avis".
--
-- The recompute trigger had the same blind spot: it updated the
-- `restaurants` view, which only exposes restaurant-category vendors, so a
-- boutique's average would never move even once the insert succeeded.
--
-- Fix: repoint the FK at vendors(id) and recompute on vendors directly.

begin;

-- Drop whatever FK currently guards order_ratings.restaurant_id, by lookup
-- rather than by name, so this works regardless of what the constraint was
-- called when the table was renamed.
do $$
declare
  c record;
begin
  for c in
    select con.conname
    from pg_constraint con
    join pg_attribute a
      on a.attrelid = con.conrelid and a.attnum = any (con.conkey)
    where con.conrelid = 'public.order_ratings'::regclass
      and con.contype = 'f'
      and a.attname = 'restaurant_id'
  loop
    execute format('alter table public.order_ratings drop constraint %I', c.conname);
  end loop;
end $$;

-- NOT VALID: enforced for every new rating, without re-checking old rows
-- (vendors reuses the legacy ids, so they match anyway).
alter table public.order_ratings
  add constraint order_ratings_restaurant_id_fkey
  foreign key (restaurant_id) references public.vendors (id) not valid;

create or replace function public.recompute_restaurant_rating()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.vendors
     set rating = (
           select round(coalesce(avg(r.rating), 0), 2)
           from public.order_ratings r
           where r.restaurant_id = new.restaurant_id
         ),
         review_count = (
           select count(*)
           from public.order_ratings r
           where r.restaurant_id = new.restaurant_id
         )
   where id = new.restaurant_id;
  return new;
end;
$$;

commit;
