-- Server-side enforcement of the permission keys (RLS policies, column guards, RPC checks).

alter policy products_read on public.products using (active or public.is_staff());
alter policy products_write on public.products
  using (public.has_perm('catalog_edit') or public.has_perm('prices_edit'))
  with check (public.has_perm('catalog_edit') or public.has_perm('prices_edit'));
alter policy variants_write on public.product_variants
  using (public.has_perm('catalog_edit') or public.has_perm('stock_edit'))
  with check (public.has_perm('catalog_edit') or public.has_perm('stock_edit'));

-- column-level rules for signed-in team members (server-side RPCs run as the table owner and are not affected)
create or replace function public.guard_products() returns trigger
language plpgsql as $$
begin
  if current_user <> 'authenticated' then return coalesce(new, old); end if;
  if tg_op in ('INSERT', 'DELETE') then
    if not public.has_perm('catalog_edit') then raise exception 'FORBIDDEN'; end if;
    return coalesce(new, old);
  end if;
  if (new.price is distinct from old.price or new.compare_at_price is distinct from old.compare_at_price)
     and not public.has_perm('prices_edit') then raise exception 'FORBIDDEN'; end if;
  if (to_jsonb(new) - 'price' - 'compare_at_price') is distinct from (to_jsonb(old) - 'price' - 'compare_at_price')
     and not public.has_perm('catalog_edit') then raise exception 'FORBIDDEN'; end if;
  return new;
end $$;
create trigger products_guard before insert or update or delete on public.products
  for each row execute function public.guard_products();

create or replace function public.guard_variants() returns trigger
language plpgsql as $$
begin
  if current_user <> 'authenticated' then return coalesce(new, old); end if;
  if tg_op in ('INSERT', 'DELETE') then
    if not public.has_perm('catalog_edit') then raise exception 'FORBIDDEN'; end if;
    return coalesce(new, old);
  end if;
  if new.stock is distinct from old.stock and not public.has_perm('stock_edit') then raise exception 'FORBIDDEN'; end if;
  if (to_jsonb(new) - 'stock') is distinct from (to_jsonb(old) - 'stock') and not public.has_perm('catalog_edit') then raise exception 'FORBIDDEN'; end if;
  return new;
end $$;
create trigger variants_guard before insert or update or delete on public.product_variants
  for each row execute function public.guard_variants();

alter policy orders_read on public.orders using (customer_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')));
alter policy order_items_read on public.order_items using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')))));
alter policy order_hist_read on public.order_status_history using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')))));
alter policy conv_read on public.support_conversations using (customer_id = auth.uid() or public.has_perm('chat'));
alter policy msg_read on public.support_messages using (
  exists (select 1 from public.support_conversations c where c.id = conversation_id
          and (c.customer_id = auth.uid() or public.has_perm('chat'))));
alter policy msg_insert_staff on public.support_messages with check (
  sender_kind = 'staff' and sender_id = auth.uid() and public.has_perm('chat'));

create or replace function public.support_mark_read(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.has_perm('chat') then
    update support_conversations set staff_unread = 0 where id = p_conv;
  else
    update support_conversations set customer_unread = 0 where id = p_conv and customer_id = auth.uid();
  end if;
end $$;

create or replace function public.support_close(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (public.has_perm('chat')
          or exists (select 1 from support_conversations where id = p_conv and customer_id = auth.uid())) then raise exception 'FORBIDDEN'; end if;
  update support_conversations set status = 'closed' where id = p_conv;
end $$;

create or replace function public.pick_agent(p_roles text[], p_kind text) returns uuid
language sql stable security definer set search_path = public as $$
  select p.id from profiles p
  where p.is_active and p.role = any(p_roles)
    and (p.role = 'owner' or (case when p_kind = 'order' then 'orders_manage' else 'chat' end) = any(p.perms))
  order by (coalesce(p.online_at, 'epoch') > now() - interval '10 minutes') desc,
    case when p_kind = 'order'
      then (select count(*) from orders o where o.assigned_to = p.id and o.status in ('new','confirmed','packed','shipped'))
      else (select count(*) from support_conversations c where c.assigned_to = p.id and c.status = 'open') end asc,
    random()
  limit 1
$$;
-- NOTE: set_order_status, dashboard_stats, list_customers and set_customer_blocked are defined in 0006.
