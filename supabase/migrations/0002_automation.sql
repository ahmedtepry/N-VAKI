-- NŌVAKI automation: orders, auto-assignment, notifications, support chat, dashboard, seed.

create or replace function public.notify(p_user uuid, p_title_ar text, p_title_en text, p_body_ar text, p_body_en text, p_kind text, p_ref uuid)
returns void language sql security definer set search_path = public as $$
  insert into notifications(user_id, title_ar, title_en, body_ar, body_en, kind, ref_id)
  values (p_user, p_title_ar, p_title_en, p_body_ar, p_body_en, p_kind, p_ref)
$$;

create or replace function public.notify_roles(p_roles text[], p_title_ar text, p_title_en text, p_body_ar text, p_body_en text, p_kind text, p_ref uuid)
returns void language sql security definer set search_path = public as $$
  insert into notifications(user_id, title_ar, title_en, body_ar, body_en, kind, ref_id)
  select id, p_title_ar, p_title_en, p_body_ar, p_body_en, p_kind, p_ref
  from profiles where is_active and role = any(p_roles)
$$;

-- least-loaded active team member of the given roles, preferring people seen in the last 10 minutes
create or replace function public.pick_agent(p_roles text[], p_kind text) returns uuid
language sql stable security definer set search_path = public as $$
  select p.id from profiles p
  where p.is_active and p.role = any(p_roles)
  order by (coalesce(p.online_at, 'epoch') > now() - interval '10 minutes') desc,
    case when p_kind = 'order'
      then (select count(*) from orders o where o.assigned_to = p.id and o.status in ('new','confirmed','packed','shipped'))
      else (select count(*) from support_conversations c where c.assigned_to = p.id and c.status = 'open') end asc,
    random()
  limit 1
$$;

create or replace function public.assign_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_agent uuid; v_no bigint;
begin
  v_agent := public.pick_agent(array['fulfillment'], 'order');
  if v_agent is null then v_agent := public.pick_agent(array['manager','owner'], 'order'); end if;
  if v_agent is null then return; end if;
  update orders set assigned_to = v_agent where id = p_order and assigned_to is null returning order_no into v_no;
  if v_no is not null then
    perform public.notify(v_agent, 'طلب جديد #' || v_no, 'New order #' || v_no, 'تم تعيين الطلب لك تلقائيًا.', 'This order was assigned to you automatically.', 'order_assigned', p_order);
  end if;
end $$;

create or replace function public.assign_conversation(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_agent uuid; v_name text;
begin
  v_agent := public.pick_agent(array['support'], 'chat');
  if v_agent is null then v_agent := public.pick_agent(array['manager','owner'], 'chat'); end if;
  if v_agent is null then return; end if;
  select full_name into v_name from profiles where id = v_agent;
  update support_conversations set assigned_to = v_agent, agent_name = v_name where id = p_conv and assigned_to is null;
  if found then
    perform public.notify(v_agent, 'محادثة جديدة', 'New conversation', 'تم تعيين محادثة عميل لك تلقائيًا.', 'A customer conversation was assigned to you.', 'chat_assigned', p_conv);
  end if;
end $$;

-- place an order atomically: locks stock, snapshots names/prices, auto-assigns, notifies
create or replace function public.place_order(p_items jsonb, p_name text, p_phone text, p_address text, p_city text, p_notes text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid(); v_order uuid; v_no bigint; v_sub numeric := 0; v_ship numeric; v_free numeric;
  it jsonb; v record; v_qty int;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'CART_EMPTY'; end if;
  if length(trim(coalesce(p_name,''))) < 2 or length(regexp_replace(coalesce(p_phone,''), '\D', '', 'g')) < 8
     or length(trim(coalesce(p_address,''))) < 5 then raise exception 'INVALID_INPUT'; end if;

  insert into orders(customer_id, customer_name, phone, address, city, notes)
  values (v_uid, trim(p_name), trim(p_phone), trim(p_address), trim(coalesce(p_city,'')), nullif(trim(coalesce(p_notes,'')), ''))
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

  select coalesce((select value::numeric from app_settings where key = 'shipping_fee'), 0),
         coalesce((select value::numeric from app_settings where key = 'free_shipping_over'), 0)
    into v_ship, v_free;
  if v_free > 0 and v_sub >= v_free then v_ship := 0; end if;
  update orders set subtotal = v_sub, shipping_fee = v_ship, total = v_sub + v_ship where id = v_order;
  insert into order_status_history(order_id, status, note) values (v_order, 'new', null);

  perform public.assign_order(v_order);
  perform public.notify(v_uid, 'تم استلام طلبك #' || v_no, 'Order #' || v_no || ' received',
    'هنراجع الطلب ونأكده معاك قريب.', 'We are reviewing it and will confirm shortly.', 'order_status', v_order);
  perform public.notify_roles(array['owner','manager'], 'طلب جديد #' || v_no, 'New order #' || v_no,
    'بإجمالي ' || (v_sub + v_ship)::text, 'Total ' || (v_sub + v_ship)::text, 'order_new', v_order);
  return v_order;
end $$;

create or replace function public.set_order_status(p_order uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o orders; v_role text := public.my_role(); v_ok boolean := false; r record;
begin
  if not public.is_staff() then raise exception 'FORBIDDEN'; end if;
  select * into v_o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  v_ok := (v_o.status = 'new' and p_status in ('confirmed','cancelled'))
       or (v_o.status = 'confirmed' and p_status in ('packed','cancelled'))
       or (v_o.status = 'packed' and p_status in ('shipped','cancelled'))
       or (v_o.status = 'shipped' and p_status in ('delivered','cancelled'));
  if not v_ok then raise exception 'INVALID_INPUT'; end if;
  if v_role = 'support' and p_status not in ('confirmed','cancelled') then raise exception 'FORBIDDEN'; end if;

  update orders set status = p_status, updated_at = now(), assigned_to = coalesce(assigned_to, auth.uid()) where id = p_order;
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

create or replace function public.cancel_my_order(p_order uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_o orders; r record;
begin
  select * into v_o from orders where id = p_order and customer_id = auth.uid() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_o.status <> 'new' then raise exception 'CANNOT_CANCEL'; end if;
  update orders set status = 'cancelled', updated_at = now() where id = p_order;
  insert into order_status_history(order_id, status, note, changed_by) values (p_order, 'cancelled', 'customer', auth.uid());
  for r in select variant_id, qty from order_items where order_id = p_order and variant_id is not null loop
    update product_variants set stock = stock + r.qty where id = r.variant_id;
  end loop;
  perform public.notify_roles(array['owner','manager'], 'العميل ألغى الطلب #' || v_o.order_no, 'Customer cancelled #' || v_o.order_no, '', '', 'order_cancelled', p_order);
end $$;

-- support chat ----------------------------------------------------------------
create or replace function public.support_open(p_subject text default null, p_order uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_conv uuid; v_agent text; v_hours text;
begin
  if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
  select id into v_conv from support_conversations where customer_id = v_uid and status = 'open';
  if v_conv is not null then return v_conv; end if;
  insert into support_conversations(customer_id, subject, order_id) values (v_uid, nullif(trim(coalesce(p_subject,'')), ''), p_order) returning id into v_conv;
  perform public.assign_conversation(v_conv);
  select agent_name into v_agent from support_conversations where id = v_conv;
  select value into v_hours from app_settings where key = 'support_hours_ar';
  insert into support_messages(conversation_id, sender_kind, body)
  values (v_conv, 'bot', case when v_agent is null
    then 'أهلاً بيك في NŌVAKI 👋 اكتب سؤالك وفريقنا هيرد عليك في أقرب وقت.'
    else 'أهلاً بيك في NŌVAKI 👋 ' || v_agent || ' من فريق خدمة العملاء معاك دلوقتي. اكتب سؤالك.' end);
  return v_conv;
end $$;

create or replace function public.support_message_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare c support_conversations; v_online boolean; v_recent_bot boolean;
begin
  select * into c from support_conversations where id = new.conversation_id;
  if new.sender_kind = 'customer' then
    update support_conversations set last_message_at = now(), staff_unread = staff_unread + 1 where id = c.id;
    if c.assigned_to is null then perform public.assign_conversation(c.id); select * into c from support_conversations where id = c.id; end if;
    if c.assigned_to is not null then
      perform public.notify(c.assigned_to, 'رسالة من عميل', 'Customer message', left(new.body, 120), left(new.body, 120), 'chat_message', c.id);
    else
      perform public.notify_roles(array['owner','manager','support'], 'رسالة من عميل', 'Customer message', left(new.body, 120), left(new.body, 120), 'chat_message', c.id);
    end if;
    -- automatic reply when nobody is around
    select coalesce((select online_at > now() - interval '10 minutes' from profiles where id = c.assigned_to), false) into v_online;
    select exists (select 1 from support_messages where conversation_id = c.id and sender_kind = 'bot' and created_at > now() - interval '1 hour' and body like 'فريق%') into v_recent_bot;
    if not v_online and not v_recent_bot then
      insert into support_messages(conversation_id, sender_kind, body)
      values (c.id, 'bot', 'فريق خدمة العملاء مش متاح لحظيًا، وهنرد عليك أول ما نرجع. ساعات العمل: ' || coalesce((select value from app_settings where key = 'support_hours_ar'), ''));
    end if;
  elsif new.sender_kind = 'staff' then
    update support_conversations set last_message_at = now(), customer_unread = customer_unread + 1, staff_unread = 0,
      assigned_to = coalesce(assigned_to, new.sender_id),
      agent_name = coalesce(agent_name, (select full_name from profiles where id = new.sender_id)) where id = c.id;
    perform public.notify(c.customer_id, 'رد جديد من خدمة العملاء', 'New reply from support', left(new.body, 120), left(new.body, 120), 'chat_message', c.id);
  end if;
  return new;
end $$;
create trigger support_message_after after insert on public.support_messages
  for each row execute function public.support_message_after();

create or replace function public.support_mark_read(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.has_role(array['owner','manager','support']) then
    update support_conversations set staff_unread = 0 where id = p_conv;
  else
    update support_conversations set customer_unread = 0 where id = p_conv and customer_id = auth.uid();
  end if;
end $$;

create or replace function public.support_close(p_conv uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not (public.has_role(array['owner','manager','support'])
          or exists (select 1 from support_conversations where id = p_conv and customer_id = auth.uid())) then raise exception 'FORBIDDEN'; end if;
  update support_conversations set status = 'closed' where id = p_conv;
end $$;

-- team --------------------------------------------------------------------------
create or replace function public.touch_presence() returns text
language plpgsql security definer set search_path = public as $$
declare v_role text := public.my_role(); r record;
begin
  if auth.uid() is null then return 'anon'; end if;
  update profiles set online_at = now() where id = auth.uid();
  -- a team member coming online picks up anything still waiting for an owner
  if v_role = 'support' then
    for r in select id from support_conversations where status = 'open' and assigned_to is null loop perform public.assign_conversation(r.id); end loop;
  elsif v_role = 'fulfillment' then
    for r in select id from orders where status in ('new','confirmed','packed') and assigned_to is null loop perform public.assign_order(r.id); end loop;
  end if;
  return v_role;
end $$;

create or replace function public.set_user_role(p_email text, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me text := public.my_role(); v_target profiles;
begin
  if v_me not in ('owner','manager') then raise exception 'FORBIDDEN'; end if;
  if p_role not in ('customer','manager','support','fulfillment') then raise exception 'INVALID_INPUT'; end if;
  if v_me = 'manager' and p_role = 'manager' then raise exception 'FORBIDDEN'; end if;
  select * into v_target from profiles where lower(email) = lower(trim(p_email));
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_target.role = 'owner' or (v_me = 'manager' and v_target.role = 'manager') then raise exception 'FORBIDDEN'; end if;
  update profiles set role = p_role where id = v_target.id;
  if p_role <> 'customer' then
    perform public.notify(v_target.id, 'اتضفت لفريق NŌVAKI', 'You joined the NŌVAKI team', 'افتح لوحة التحكم من الحساب.', 'Open the dashboard from your account.', 'team', null);
  end if;
end $$;

create or replace function public.set_member_active(p_user uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.has_role(array['owner','manager']) then raise exception 'FORBIDDEN'; end if;
  update profiles set is_active = p_active where id = p_user and role not in ('owner');
end $$;

-- dashboard ---------------------------------------------------------------------
create or replace function public.dashboard_stats() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_today date := (now() at time zone 'Africa/Cairo')::date; v jsonb;
begin
  if not public.is_staff() then raise exception 'FORBIDDEN'; end if;
  select jsonb_build_object(
    'role', public.my_role(),
    'today_orders', (select count(*) from orders where (created_at at time zone 'Africa/Cairo')::date = v_today and status <> 'cancelled'),
    'today_revenue', coalesce((select sum(total) from orders where (created_at at time zone 'Africa/Cairo')::date = v_today and status <> 'cancelled'), 0),
    'new_orders', (select count(*) from orders where status = 'new'),
    'in_progress', (select count(*) from orders where status in ('confirmed','packed','shipped')),
    'my_orders', (select count(*) from orders where assigned_to = auth.uid() and status in ('new','confirmed','packed','shipped')),
    'open_chats', (select count(*) from support_conversations where status = 'open'),
    'my_chats', (select count(*) from support_conversations where status = 'open' and assigned_to = auth.uid()),
    'unassigned_chats', (select count(*) from support_conversations where status = 'open' and assigned_to is null),
    'low_stock', (select count(*) from product_variants pv join products p on p.id = pv.product_id where p.active and pv.stock <= 3),
    'customers', (select count(*) from profiles where role = 'customer'),
    'week', coalesce((select jsonb_agg(jsonb_build_object('d', d::text, 'revenue', coalesce(r, 0), 'orders', coalesce(n, 0)) order by d)
        from (select (v_today - 6 + g) d, (select sum(total) from orders o where (o.created_at at time zone 'Africa/Cairo')::date = (v_today - 6 + g) and o.status <> 'cancelled') r,
                     (select count(*) from orders o where (o.created_at at time zone 'Africa/Cairo')::date = (v_today - 6 + g) and o.status <> 'cancelled') n
              from generate_series(0, 6) g) w), '[]'::jsonb),
    'top_products', coalesce((select jsonb_agg(t) from (
        select name_ar, name_en, sum(qty)::int as qty from order_items oi join orders o on o.id = oi.order_id
        where o.status <> 'cancelled' and o.created_at > now() - interval '30 days' group by name_ar, name_en order by sum(qty) desc limit 5) t), '[]'::jsonb),
    'team', case when public.has_role(array['owner','manager']) then coalesce((select jsonb_agg(m) from (
        select p.id, p.full_name, p.email, p.role, p.is_active,
               (coalesce(p.online_at, 'epoch') > now() - interval '10 minutes') as online,
               (select count(*) from orders o where o.assigned_to = p.id and o.status in ('new','confirmed','packed','shipped')) as open_orders,
               (select count(*) from support_conversations c where c.assigned_to = p.id and c.status = 'open') as open_chats
        from profiles p where p.role <> 'customer' order by p.role, p.full_name) m), '[]'::jsonb) else '[]'::jsonb end
  ) into v;
  return v;
end $$;

-- lock down execution: only signed-in users call the RPCs; helpers stay internal
revoke execute on all functions in schema public from public, anon;
grant execute on function public.place_order(jsonb, text, text, text, text, text) to authenticated;
grant execute on function public.set_order_status(uuid, text, text) to authenticated;
grant execute on function public.cancel_my_order(uuid) to authenticated;
grant execute on function public.support_open(text, uuid) to authenticated;
grant execute on function public.support_mark_read(uuid) to authenticated;
grant execute on function public.support_close(uuid) to authenticated;
grant execute on function public.touch_presence() to authenticated;
grant execute on function public.set_user_role(text, text) to authenticated;
grant execute on function public.set_member_active(uuid, boolean) to authenticated;
grant execute on function public.dashboard_stats() to authenticated;
grant execute on function public.my_role() to authenticated, anon;
grant execute on function public.has_role(text[]) to authenticated, anon;
grant execute on function public.is_staff() to authenticated, anon;
