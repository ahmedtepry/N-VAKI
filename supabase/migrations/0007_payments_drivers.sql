-- Payments (cash / e-wallet), driver assignment, driver permissions.

alter table public.orders
  add column if not exists payment_method text not null default 'cod' check (payment_method in ('cod','wallet')),
  add column if not exists payment_status text not null default 'unpaid' check (payment_status in ('unpaid','sent','paid')),
  add column if not exists wallet_ref text,
  add column if not exists paid_at timestamptz,
  add column if not exists driver_id uuid references public.profiles(id) on delete set null;

insert into public.app_settings(key, value) values ('wallet_number', '01118819464') on conflict (key) do nothing;

create or replace function public.all_perms() returns text[] language sql immutable as $$
  select array['orders_view','orders_manage','chat','catalog_edit','prices_edit','stock_edit','categories_edit','sizes_edit',
               'coupons_edit','settings_edit','customers_view','customers_block','reports_view','drivers_assign','driver']
$$;

create or replace function public.role_perms(p_role text) returns text[] language sql immutable as $$
  select case p_role
    when 'owner' then public.all_perms()
    when 'manager' then array['orders_view','orders_manage','chat','catalog_edit','prices_edit','stock_edit','categories_edit','sizes_edit','coupons_edit','customers_view','reports_view','drivers_assign']
    when 'support' then array['orders_view','orders_manage','chat','customers_view']
    when 'fulfillment' then array['orders_view','orders_manage','stock_edit']
    else '{}'::text[] end
$$;

update public.profiles set perms = array_append(perms, 'drivers_assign')
 where role = 'manager' and not ('drivers_assign' = any(perms));

create or replace function public.notify_perm(p_perm text, p_title_ar text, p_title_en text, p_body_ar text, p_body_en text, p_kind text, p_ref uuid)
returns void language sql security definer set search_path = public as $$
  insert into notifications(user_id, title_ar, title_en, body_ar, body_en, kind, ref_id)
  select id, p_title_ar, p_title_en, p_body_ar, p_body_en, p_kind, p_ref
  from profiles where is_active and role <> 'customer' and (role = 'owner' or p_perm = any(perms))
$$;

alter policy orders_read on public.orders using (customer_id = auth.uid() or driver_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')));
alter policy order_items_read on public.order_items using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or o.driver_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')))));
alter policy order_hist_read on public.order_status_history using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or o.driver_id = auth.uid() or (public.is_staff() and public.has_perm('orders_view')))));

create or replace function public.place_order_v3(p_items jsonb, p_name text, p_phone text, p_address text, p_city text, p_notes text,
  p_coupon text, p_lat double precision, p_lng double precision, p_payment text default 'cod')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; o orders; v_wallet text;
begin
  if p_payment not in ('cod','wallet') then raise exception 'INVALID_INPUT'; end if;
  v_id := public.place_order_v2(p_items, p_name, p_phone, p_address, p_city, p_notes, p_coupon, p_lat, p_lng);
  if p_payment = 'wallet' then
    select * into o from orders where id = v_id;
    select value into v_wallet from app_settings where key = 'wallet_number';
    update orders set payment_method = 'wallet' where id = v_id;
    insert into order_status_history(order_id, status, note) values (v_id, o.status, 'الدفع بمحفظة إلكترونية على ' || coalesce(v_wallet, ''));
    perform public.notify_perm('orders_manage',
      'طلب #' || o.order_no || ' هيدفع بمحفظة إلكترونية', 'Order #' || o.order_no || ' pays by e-wallet',
      'العميل ' || o.customer_name || ' (' || o.phone || ') هيحوّل ' || o.total::text || ' على الرقم ' || coalesce(v_wallet, ''),
      o.customer_name || ' (' || o.phone || ') will transfer ' || o.total::text || ' to ' || coalesce(v_wallet, ''),
      'order_new', v_id);
  end if;
  return v_id;
end $$;

revoke execute on function public.place_order_v2(jsonb, text, text, text, text, text, text, double precision, double precision) from authenticated;
grant execute on function public.place_order_v3(jsonb, text, text, text, text, text, text, double precision, double precision, text) to authenticated;

create or replace function public.wallet_mark_sent(p_order uuid, p_ref text default null) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; v_wallet text;
begin
  select * into o from orders where id = p_order and customer_id = auth.uid() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.payment_method <> 'wallet' or o.payment_status <> 'unpaid' or o.status = 'cancelled' then raise exception 'INVALID_INPUT'; end if;
  select value into v_wallet from app_settings where key = 'wallet_number';
  update orders set payment_status = 'sent', wallet_ref = nullif(trim(coalesce(p_ref, '')), '') where id = p_order;
  insert into order_status_history(order_id, status, note) values (p_order, o.status, 'العميل بلّغ إنه حوّل المبلغ');
  perform public.notify_perm('orders_manage',
    'تحويل محفظة للطلب #' || o.order_no, 'Wallet transfer for order #' || o.order_no,
    o.customer_name || ' بيقول حوّل ' || o.total::text || ' على ' || coalesce(v_wallet, '') || coalesce(' — من رقم/مرجع: ' || nullif(trim(coalesce(p_ref, '')), ''), ''),
    o.customer_name || ' says they sent ' || o.total::text || ' to ' || coalesce(v_wallet, ''),
    'order_new', p_order);
end $$;

create or replace function public.confirm_payment(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  if not public.has_perm('orders_manage') then raise exception 'FORBIDDEN'; end if;
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.payment_status = 'paid' or o.status = 'cancelled' then raise exception 'INVALID_INPUT'; end if;
  update orders set payment_status = 'paid', paid_at = now() where id = p_order;
  insert into order_status_history(order_id, status, note, changed_by) values (p_order, o.status, 'تم تأكيد الدفع', auth.uid());
  perform public.notify(o.customer_id, 'تم استلام الدفع للطلب #' || o.order_no, 'Payment received for order #' || o.order_no,
    'شكرًا! استلمنا المبلغ وبنجهّز طلبك.', 'Thanks! We received your payment and are preparing your order.', 'order_status', p_order);
end $$;

grant execute on function public.wallet_mark_sent(uuid, text) to authenticated;
grant execute on function public.confirm_payment(uuid) to authenticated;
