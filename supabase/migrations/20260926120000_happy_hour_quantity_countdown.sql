-- Make the Happy Hour "quantity" real: count it down, stop at zero
-- ============================================================================
-- A partner can offer a limited batch at the happy-hour price ("7 pizzas"),
-- stored in vendor_items.discount_quantity. Nothing ever decremented it: the
-- client showed "Only 7 left!" forever and sold unlimited units at the
-- discount.
--
-- This trigger runs on every new order line. If the item has a live, limited
-- happy hour (discount_price set, quantity set, not past its end time), the
-- ordered quantity is taken off. When it reaches 0 the deal is ended — price,
-- end time and quantity cleared — so the next customer pays the normal price
-- and the item drops off the Happy Hour lists.
--
-- Every order line carries exactly one of food_item_id / grocery_item_id /
-- vendor_item_id, and all three are vendor_items ids (food_items and
-- grocery_items are views over vendor_items exposing vi.id), so one lookup
-- covers every shop category.
--
-- SECURITY DEFINER: the customer placing the order has no write access to
-- vendor_items, and must not be given any.

begin;

create or replace function public.consume_happy_hour_quantity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_item uuid := coalesce(new.vendor_item_id, new.food_item_id, new.grocery_item_id);
begin
  if v_item is null then
    return new;
  end if;

  update public.vendor_items
     set discount_quantity = greatest(discount_quantity - coalesce(new.quantity, 1), 0)
   where id = v_item
     and discount_price is not null
     and discount_quantity is not null
     and (discount_end_time is null or discount_end_time > now());

  -- Sold out: end the deal so nobody else gets the happy-hour price.
  update public.vendor_items
     set discount_price = null,
         discount_end_time = null,
         discount_quantity = null
   where id = v_item
     and discount_quantity is not null
     and discount_quantity <= 0;

  return new;
end;
$$;

drop trigger if exists on_order_item_consume_happy_hour on public.order_items;
create trigger on_order_item_consume_happy_hour
after insert on public.order_items
for each row
execute function public.consume_happy_hour_quantity();

commit;
