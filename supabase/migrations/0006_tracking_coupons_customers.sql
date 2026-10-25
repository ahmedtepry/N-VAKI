-- Order tracking with map locations, coupons at checkout, customers list, permission-aware dashboard.

alter table public.orders
  add column if not exists dest_lat double precision,
  add column if not exists dest_lng double precision,
  add column if not exists courier_lat double precision,
  add column if not exists courier_lng double precision,
  add column if not exists courier_at timestamptz,
  add column if not exists delivery_eta timestamptz,
  add column if not exists courier_name text,
  add column if not exists courier_phone text;

create or replace function public.km_between(a_lat double precision, a_lng double precision, b_lat double precision, b_lng double precision)
returns double precision language sql immutable as $$
  select 12742 * asin(sqrt(power(sin(radians(b_lat - a_lat) / 2), 2) + cos(radians(a_lat)) * cos(radians(b_lat)) * power(sin(radians(b_lng - a_lng) / 2), 2)))
$$;

create or replace function public.courier_ping(p_order uuid, p_lat double precision, p_lng double precision) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; me profiles;
begin
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status <> 'shipped' or not (o.assigned_to = auth.uid() or public.has_perm('orders_manage')) then raise exception 'FORBIDDEN'; end if;
  if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'INVALID_INPUT'; end if;
  select * into me from profiles where id = auth.uid();
  update orders set courier_lat = p_lat, courier_lng = p_lng, courier_at = now(),
    courier_name = coalesce(courier_name, me.full_name), courier_phone = coalesce(courier_phone, me.phone),
    delivery_eta = case when dest_lat is null then delivery_eta
      else now() + make_interval(mins => (public.km_between(p_lat, p_lng, dest_lat, dest_lng) / 22.0 * 60 + 3)::int) end
  where id = p_order;
end $$;

create or replace function public.orders_courier_identity() returns trigger
language plpgsql security definer set search_path = public as $$
declare pr profiles;
begin
  if new.status = 'shipped' and old.status is distinct from 'shipped' then
    select * into pr from profiles where id = coalesce(new.assigned_to, auth.uid());
    new.courier_name := coalesce(pr.full_name, new.courier_name);
    new.courier_phone := coalesce(pr.phone, new.courier_phone);
  end if;
  return new;
end $$;
create trigger orders_courier_identity before update of status on public.orders
  for each row execute function public.orders_courier_identity();

create or replace function public.post_order_update(p_order uuid, p_message text) returns void
language plpgsql security definer set search_path = public as $$
declare o orders;
begin
  if not public.has_perm('orders_manage') then raise exception 'FORBIDDEN'; end if;
  if length(trim(coalesce(p_message, ''))) < 2 then raise exception 'INVALID_INPUT'; end if;
  select * into o from orders where id = p_order;
  if not found then raise exception 'NOT_FOUND'; end if;
  insert into order_status_history(order_id, status, note, changed_by) values (p_order, o.status, trim(p_message), auth.uid());
  perform public.notify(o.customer_id, 'تحديث على طلبك #' || o.order_no, 'Update on order #' || o.order_no, trim(p_message), trim(p_message), 'order_status', p_order);
end $$;

create or replace function public.track_order(p_no bigint, p_phone text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o orders; v_digits text := right(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 8);
begin
  if length(v_digits) < 8 then return null; end if;
  select * into o from orders where order_no = p_no and right(regexp_replace(phone, '\D', '', 'g'), 8) = v_digits;
  if not found then return null; end if;
  return jsonb_build_object(
    'order_no', o.order_no, 'status', o.status, 'created_at', o.created_at, 'total', o.total, 'city', o.city,
    'dest_lat', o.dest_lat, 'dest_lng', o.dest_lng, 'delivery_eta', o.delivery_eta,
    'courier_name', case when o.status = 'shipped' then o.courier_name end,
    'courier_phone', case when o.status = 'shipped' then o.courier_phone end,
    'courier_lat', case when o.status = 'shipped' then o.courier_lat end,
    'courier_lng', case when o.status = 'shipped' then o.courier_lng end,
    'courier_at', case when o.status = 'shipped' then o.courier_at end,
    'timeline', coalesce((select jsonb_agg(jsonb_build_object('status', h.status, 'note', h.note, 'at', h.created_at) order by h.created_at)
                          from order_status_history h where h.order_id = o.id), '[]'::jsonb));
end $$;

create or replace function public.coupon_discount(p_code text, p_subtotal numeric) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare c coupons;
begin
  select * into c from coupons where code = upper(trim(coalesce(p_code, ''))) and active;
  if not found then raise exception 'COUPON_INVALID'; end if;
  if c.expires_at is not null and c.expires_at < now() then raise exception 'COUPON_EXPIRED'; end if;
  if c.max_uses > 0 and c.used >= c.max_uses then raise exception 'COUPON_USED_UP'; end if;
  if p_subtotal < c.min_order then raise exception 'COUPON_MIN_ORDER'; end if;
  return least(p_subtotal, case c.kind when 'percent' then round(p_subtotal * least(c.value, 100) / 100, 2) else c.value end);
end $$;

create or replace function public.validate_coupon(p_code text, p_subtotal numeric) returns numeric
language sql stable security definer set search_path = public as $$
  select public.coupon_discount(p_code, p_subtotal)
$$;

create or replace function public.place_order_v2(p_items jsonb, p_name text, p_phone text, p_address text, p_city text, p_notes text default null,
  p_coupon text default null, p_lat double precision default null, p_lng double precision default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_order uuid; v_no bigint; v_sub numeric := 0; v_ship numeric; v_free numeric; v_disc numeric := 0;
  it jsonb; v record; v_qty int; v_code text := nullif(upper(trim(coalesce(p_coupon, ''))), '');
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if not exists (select 1 from profiles where id = v_uid and is_active) then raise exception 'BLOCKED'; end if;
  if coalesce((select value from app_settings where key = 'store_open'), 'true') = 'false' then raise exception 'STORE_CLOSED'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'CART_EMPTY'; end if;
  if length(trim(coalesce(p_name,''))) < 2 or length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) < 8
     or length(trim(coalesce(p_address,''))) < 5 then raise exception 'INVALID_INPUT'; end if;
  if p_lat is not null and (p_lat not between -90 and 90 or p_lng is null or p_lng not between -180 and 180) then raise exception 'INVALID_INPUT'; end if;

  insert into orders(customer_id, customer_name, phone, address, city, notes, dest_lat, dest_lng)
  values (v_uid, trim(p_name), trim(p_phone), trim(p_address), trim(coalesce(p_city,'')), nullif(trim(coalesce(p_notes,'')), ''), p_lat, p_lng)
  returning id, order_no into v_order, v_no;

  for it in select * from jsonb_array_elements(p_items) loop
    v_qty := (it->>'qty')::int;
    if v_qty is null or v_qty < 1 or v_qty > 20 then raise exception 'INVALID_INPUT'; end if;
    select pv.id as variant_id, pv.product_id, pv.color_name_ar, pv.color_name_en, pv.color_hex, pv.size, pv.stock,
           p.name_ar, p.name_en, p.price, p.active, p.garment
      into v
      from product_variants pv join products p on p.id = pv.product_id
     where pv.id = (it->>'variant_id')::uuid
       for update of pv;
    if not found or not v.active then raise exception 'PRODUCT_UNAVAILABLE'; end if;
    if v.stock < v_qty then raise exception 'OUT_OF_STOCK'; end if;
    update product_variants set stock = stock - v_qty where id = v.variant_id;
    insert into order_items(order_id, product_id, variant_id, name_ar, name_en, color_name_ar, color_name_en, color_hex, garment, size, unit_price, qty)
    values (v_order, v.product_id, v.variant_id, v.name_ar, v.name_en, v.color_name_ar, v.color_name_en, v.color_hex, v.garment, v.size, v.price, v_qty);
    v_sub := v_sub + v.price * v_qty;
  end loop;

  if v_code is not null then
    v_disc := public.coupon_discount(v_code, v_sub);
    update coupons set used = used + 1 where code = v_code;
  end if;

  select coalesce((select value::numeric from app_settings where key = 'shipping_fee'), 0),
         coalesce((select value::numeric from app_settings where key = 'free_shipping_over'), 0)
    into v_ship, v_free;
  if v_free > 0 and (v_sub - v_disc) >= v_free then v_ship := 0; end if;
  update orders set subtotal = v_sub, discount = v_disc, coupon_code = case when v_disc > 0 then v_code end,
         shipping_fee = v_ship, total = v_sub - v_disc + v_ship where id = v_order;
  insert into order_status_history(order_id, status, note) values (v_order, 'new', null);

  perform public.assign_order(v_order);
  perform public.notify(v_uid, 'تم استلام طلبك #' || v_no, 'Order #' || v_no || ' received',
    'هنراجع الطلب ونأكده معاك قريب.', 'We are reviewing it and will confirm shortly.', 'order_status', v_order);
  perform public.notify_roles(array['owner','manager'], 'طلب جديد #' || v_no, 'New order #' || v_no,
    'بإجمالي ' || (v_sub - v_disc + v_ship)::text, 'Total ' || (v_sub - v_disc + v_ship)::text, 'order_new', v_order);
  return v_order;
end $$;

revoke execute on function public.place_order(jsonb, text, text, text, text, text) from authenticated;

create or replace function public.set_order_status(p_order uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o orders; v_role text := public.my_role(); v_ok boolean := false; r record;
begin
  if not public.has_perm('orders_manage') then raise exception 'FORBIDDEN'; end if;
  select * into v_o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  v_ok := (v_o.status = 'new' and p_status in ('confirmed','cancelled'))
       or (v_o.status = 'confirmed' and p_status in ('packed','cancelled'))
       or (v_o.status = 'packed' and p_status in ('shipped','cancelled'))
       or (v_o.status = 'shipped' and p_status in ('delivered','cancelled'));
  if not v_ok then raise exception 'INVALID_INPUT'; end if;
  if v_role = 'support' and p_status not in ('confirmed','cancelled') then raise exception 'FORBIDDEN'; end if;

  update orders set status = p_status, updated_at = now(), assigned_to = coalesce(assigned_to, auth.uid()),
    courier_lat = case when p_status in ('delivered','cancelled') then null else courier_lat end,
    courier_lng = case when p_status in ('delivered','cancelled') then null else courier_lng end,
    delivery_eta = case when p_status in ('delivered','cancelled') then null else delivery_eta end
  where id = p_order;
  insert into order_status_history(order_id, status, note, changed_by) values (p_order, p_status, nullif(trim(coalesce(p_note,'')), ''), auth.uid());

  if p_status = 'cancelled' then
    for r in select variant_id, qty from order_items where order_id = p_order and variant_id is not null loop
      update product_variants set stock = stock + r.qty where id = r.variant_id;
    end loop;
  end if;

  perform public.notify(v_o.customer_id,
    case p_status when 'confirmed' then 'تم تأكيد طلبك #' when 'packed' then 'جاري تجهيز طلبك #' when 'shipped' then 'طلبك خرج للتوصيل #'
                  when 'delivered' then 'تم تسليم طلبك #' else 'تم إلغاء طلبك #' end || v_o.order_no,
    case p_status when 'confirmed' then 'Order confirmed #' when 'packed' then 'Order packed #' when 'shipped' then 'Order on its way #'
                  when 'delivered' then 'Order delivered #' else 'Order cancelled #' end || v_o.order_no,
    coalesce(nullif(trim(coalesce(p_note,'')), ''), ''), coalesce(nullif(trim(coalesce(p_note,'')), ''), ''),
    'order_status', p_order);
end $$;

create or replace function public.list_customers(p_q text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.has_perm('customers_view') then raise exception 'FORBIDDEN'; end if;
  return coalesce((select jsonb_agg(c) from (
    select p.id, p.full_name, p.email, p.phone, p.is_active, p.created_at,
           (select count(*) from orders o where o.customer_id = p.id and o.status <> 'cancelled') as orders,
           coalesce((select sum(o.total) from orders o where o.customer_id = p.id and o.status <> 'cancelled'), 0) as spent
      from profiles p
     where p.role = 'customer'
       and (nullif(trim(coalesce(p_q, '')), '') is null
            or p.full_name ilike '%' || trim(p_q) || '%' or coalesce(p.email, '') ilike '%' || trim(p_q) || '%' or coalesce(p.phone, '') ilike '%' || trim(p_q) || '%')
     order by p.created_at desc limit 200) c), '[]'::jsonb);
end $$;

create or replace function public.set_customer_blocked(p_user uuid, p_blocked boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_perm('customers_block') then raise exception 'FORBIDDEN'; end if;
  update profiles set is_active = not p_blocked where id = p_user and role = 'customer';
end $$;

create or replace function public.dashboard_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_today date := (now() at time zone 'Africa/Cairo')::date; v jsonb; v_rep boolean := public.has_perm('reports_view');
        v_perms text[];
begin
  if not public.is_staff() then raise exception 'FORBIDDEN'; end if;
  select case when role = 'owner' then public.all_perms() else perms end into v_perms from profiles where id = auth.uid();
  select jsonb_build_object(
    'role', public.my_role(),
    'perms', to_jsonb(coalesce(v_perms, '{}')),
    'today_orders', case when v_rep then (select count(*) from orders where (created_at at time zone 'Africa/Cairo')::date = v_today and status <> 'cancelled') else 0 end,
    'today_revenue', case when v_rep then coalesce((select sum(total) from orders where (created_at at time zone 'Africa/Cairo')::date = v_today and status <> 'cancelled'), 0) else 0 end,
    'new_orders', case when public.has_perm('orders_view') then (select count(*) from orders where status = 'new') else 0 end,
    'in_progress', case when public.has_perm('orders_view') then (select count(*) from orders where status in ('confirmed','packed','shipped')) else 0 end,
    'my_orders', (select count(*) from orders where assigned_to = auth.uid() and status in ('new','confirmed','packed','shipped')),
    'open_chats', case when public.has_perm('chat') then (select count(*) from support_conversations where status = 'open') else 0 end,
    'my_chats', (select count(*) from support_conversations where status = 'open' and assigned_to = auth.uid()),
    'unassigned_chats', case when public.has_perm('chat') then (select count(*) from support_conversations where status = 'open' and assigned_to is null) else 0 end,
    'low_stock', (select count(*) from product_variants pv join products p on p.id = pv.product_id where p.active and pv.stock <= 3),
    'customers', case when public.has_perm('customers_view') then (select count(*) from profiles where role = 'customer') else 0 end,
    'week', case when v_rep then coalesce((select jsonb_agg(jsonb_build_object('d', d::text, 'revenue', coalesce(r, 0), 'orders', coalesce(n, 0)) order by d)
        from (select (v_today - 6 + g) d, (select sum(total) from orders o where (o.created_at at time zone 'Africa/Cairo')::date = (v_today - 6 + g) and o.status <> 'cancelled') r,
                     (select count(*) from orders o where (o.created_at at time zone 'Africa/Cairo')::date = (v_today - 6 + g) and o.status <> 'cancelled') n
              from generate_series(0, 6) g) w), '[]'::jsonb) else '[]'::jsonb end,
    'top_products', case when v_rep then coalesce((select jsonb_agg(t) from (
        select name_ar, name_en, sum(qty)::int as qty from order_items oi join orders o on o.id = oi.order_id
        where o.status <> 'cancelled' and o.created_at > now() - interval '30 days' group by name_ar, name_en order by sum(qty) desc limit 5) t), '[]'::jsonb) else '[]'::jsonb end,
    'team', case when public.my_role() = 'owner' then coalesce((select jsonb_agg(m) from (
        select p.id, p.full_name, p.email, p.role, p.is_active, p.perms,
               (coalesce(p.online_at, 'epoch') > now() - interval '10 minutes') as online,
               (select count(*) from orders o where o.assigned_to = p.id and o.status in ('new','confirmed','packed','shipped')) as open_orders,
               (select count(*) from support_conversations c where c.assigned_to = p.id and c.status = 'open') as open_chats
        from profiles p where p.role <> 'customer' order by p.role, p.full_name) m), '[]'::jsonb) else '[]'::jsonb end
  ) into v;
  return v;
end $$;

grant execute on function public.courier_ping(uuid, double precision, double precision) to authenticated;
grant execute on function public.post_order_update(uuid, text) to authenticated;
grant execute on function public.track_order(bigint, text) to authenticated, anon;
grant execute on function public.place_order_v2(jsonb, text, text, text, text, text, text, double precision, double precision) to authenticated;
grant execute on function public.validate_coupon(text, numeric) to authenticated;
grant execute on function public.list_customers(text) to authenticated;
grant execute on function public.set_customer_blocked(uuid, boolean) to authenticated;
