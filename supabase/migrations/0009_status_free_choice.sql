-- Managers may switch an order to any status (cancelled is final); drivers only packed->shipped->delivered.
create or replace function public.set_order_status(p_order uuid, p_status text, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_o orders; v_role text := public.my_role(); v_ok boolean := false; r record; v_mgr boolean := public.has_perm('orders_manage');
begin
  select * into v_o from orders where id = p_order for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if p_status not in ('new','confirmed','packed','shipped','delivered','cancelled') then raise exception 'INVALID_INPUT'; end if;
  if v_o.status = 'cancelled' or p_status = v_o.status then raise exception 'INVALID_INPUT'; end if;
  if v_mgr then
    v_ok := true;
    if v_role = 'support' and p_status not in ('confirmed','cancelled') then raise exception 'FORBIDDEN'; end if;
  else
    if not (v_o.driver_id = auth.uid() and public.has_perm('driver')) then raise exception 'FORBIDDEN'; end if;
    v_ok := (v_o.status = 'packed' and p_status = 'shipped') or (v_o.status = 'shipped' and p_status = 'delivered');
  end if;
  if not v_ok then raise exception 'FORBIDDEN'; end if;

  update orders set status = p_status, updated_at = now(), assigned_to = coalesce(assigned_to, auth.uid()),
    payment_status = case when p_status = 'delivered' and payment_method = 'cod' then 'paid' else payment_status end,
    paid_at = case when p_status = 'delivered' and payment_method = 'cod' then now() else paid_at end,
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
    case p_status when 'new' then 'طلبك رجع قيد المراجعة #' when 'confirmed' then 'تم تأكيد طلبك #' when 'packed' then 'بنجهّز طلبك #' when 'shipped' then 'طلبك خرج للتوصيل #'
                  when 'delivered' then 'تم استلام طلبك #' else 'تم إلغاء طلبك #' end || v_o.order_no,
    case p_status when 'new' then 'Order back under review #' when 'confirmed' then 'Order confirmed #' when 'packed' then 'Preparing order #' when 'shipped' then 'Order on its way #'
                  when 'delivered' then 'Order received #' else 'Order cancelled #' end || v_o.order_no,
    coalesce(nullif(trim(coalesce(p_note,'')), ''), ''), coalesce(nullif(trim(coalesce(p_note,'')), ''), ''),
    'order_status', p_order);
end $$;
