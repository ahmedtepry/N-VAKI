create or replace function public.list_drivers() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not (public.has_perm('drivers_assign') or public.has_perm('orders_manage')) then raise exception 'FORBIDDEN'; end if;
  return coalesce((select jsonb_agg(d) from (
    select p.id, p.full_name, p.phone,
           (coalesce(p.online_at, 'epoch') > now() - interval '10 minutes') as online,
           (select count(*) from orders o where o.driver_id = p.id and o.status in ('confirmed','packed','shipped')) as active
      from profiles p
     where p.is_active and p.role <> 'customer' and (p.role = 'owner' or 'driver' = any(p.perms))
     order by p.full_name) d), '[]'::jsonb);
end $$;

create or replace function public.assign_driver(p_order uuid, p_driver uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; d profiles;
begin
  if not public.has_perm('drivers_assign') then raise exception 'FORBIDDEN'; end if;
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status in ('delivered','cancelled') then raise exception 'INVALID_INPUT'; end if;
  if p_driver is null then
    update orders set driver_id = null where id = p_order;
    insert into order_status_history(order_id, status, note, changed_by) values (p_order, o.status, 'تم إلغاء تعيين السائق', auth.uid());
    return;
  end if;
  select * into d from profiles where id = p_driver and is_active and role <> 'customer' and (role = 'owner' or 'driver' = any(perms));
  if not found then raise exception 'INVALID_INPUT'; end if;
  update orders set driver_id = p_driver, courier_name = d.full_name, courier_phone = d.phone where id = p_order;
  insert into order_status_history(order_id, status, note, changed_by) values (p_order, o.status, 'تم تسليم الطلب للسائق ' || d.full_name, auth.uid());
  perform public.notify(p_driver, 'طلب جديد ليك #' || o.order_no, 'New delivery #' || o.order_no,
    o.city || ' - ' || o.address, o.city || ' - ' || o.address, 'order_new', p_order);
end $$;

grant execute on function public.list_drivers() to authenticated;
grant execute on function public.assign_driver(uuid, uuid) to authenticated;

create or replace function public.courier_ping(p_order uuid, p_lat double precision, p_lng double precision) returns void
language plpgsql security definer set search_path = public as $$
declare o orders; me profiles;
begin
  select * into o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status <> 'shipped' or not (o.driver_id = auth.uid() or (o.driver_id is null and o.assigned_to = auth.uid()) or public.has_perm('orders_manage')) then raise exception 'FORBIDDEN'; end if;
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
    select * into pr from profiles where id = coalesce(new.driver_id, new.assigned_to, auth.uid());
    new.courier_name := coalesce(pr.full_name, new.courier_name);
    new.courier_phone := coalesce(pr.phone, new.courier_phone);
  end if;
  return new;
end $$;
