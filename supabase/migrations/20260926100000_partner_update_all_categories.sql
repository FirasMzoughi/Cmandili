-- Let partners of every category accept their own orders
-- ============================================================================
-- `orders_partner_update` was written when only two verticals existed. Its
-- USING/WITH CHECK clauses match a partner row whose partner_type is exactly
-- 'restaurant' or 'supermarket':
--
--     restaurant_id IN (SELECT entity_id FROM partners
--                       WHERE user_id = auth.uid()
--                         AND partner_type = 'restaurant')
--     OR supermarket_id IN (... partner_type = 'supermarket')
--
-- A florist, pet shop, bakery, gift shop or electronics store signs up with
-- partner_type = 'flowers' | 'pets' | 'bakery' | 'gifts' | 'electronics', so
-- NEITHER branch matches. Row-level security then silently blocks the UPDATE:
-- no error is raised, the statement simply affects zero rows.
--
-- The effect, seen in the partner app: tapping "Accepter" appears to do
-- nothing. The order stays Pending forever, and because the driver dispatch
-- runs from an AFTER UPDATE OF status trigger, no driver is ever notified.
--
-- This rewrites the policy to key on the entity id alone. Which column the
-- order used (restaurant_id or supermarket_id) and which category the partner
-- sells are both irrelevant to the question being asked: does this order
-- belong to the venue this user owns?

begin;

-- Compared as TEXT on purpose, with entity_id cast explicitly. The repo's
-- schema file declares partners.entity_id TEXT, but the live column is uuid:
-- a bare `entity_id <> ''` made Postgres parse '' as a uuid and fail with
-- 22P02 before the policy was even created. Casting entity_id to text first
-- works for either column type, and a text comparison can never throw at
-- query time. Both order id columns are checked (rather than coalesce) so an
-- order carrying both still matches whichever venue owns it.

drop policy if exists "orders_partner_update" on public.orders;

create policy "orders_partner_update"
  on public.orders for update
  to authenticated
  using (
    exists (
      select 1 from public.partners p
      where p.user_id = auth.uid()
        and p.entity_id::text <> ''
        and lower(p.entity_id::text) in (orders.restaurant_id::text, orders.supermarket_id::text)
    )
  )
  with check (
    exists (
      select 1 from public.partners p
      where p.user_id = auth.uid()
        and p.entity_id::text <> ''
        and lower(p.entity_id::text) in (orders.restaurant_id::text, orders.supermarket_id::text)
    )
  );

-- Same blind spot on SELECT: a gift-shop partner could not even read their
-- own orders back, which is why the list could look stale after an action.
drop policy if exists "orders_partner_select" on public.orders;

create policy "orders_partner_select"
  on public.orders for select
  to authenticated
  using (
    exists (
      select 1 from public.partners p
      where p.user_id = auth.uid()
        and p.entity_id::text <> ''
        and lower(p.entity_id::text) in (orders.restaurant_id::text, orders.supermarket_id::text)
    )
  );

commit;
