-- NŌVAKI granular permissions: the owner decides exactly what every team member may do.

alter table public.profiles add column if not exists perms text[] not null default '{}';

create or replace function public.all_perms() returns text[] language sql immutable as $$
  select array['orders_view','orders_manage','chat','catalog_edit','prices_edit','stock_edit','categories_edit','sizes_edit',
               'coupons_edit','settings_edit','customers_view','customers_block','reports_view']
$$;

create or replace function public.role_perms(p_role text) returns text[] language sql immutable as $$
  select case p_role
    when 'owner' then public.all_perms()
    when 'manager' then array['orders_view','orders_manage','chat','catalog_edit','prices_edit','stock_edit','categories_edit','sizes_edit','coupons_edit','customers_view','reports_view']
    when 'support' then array['orders_view','orders_manage','chat','customers_view']
    when 'fulfillment' then array['orders_view','orders_manage','stock_edit']
    else '{}'::text[] end
$$;

create or replace function public.has_perm(p_perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select (role = 'owner') or (p_perm = any(perms)) from profiles
                   where id = auth.uid() and is_active and role <> 'customer'), false)
$$;

create or replace function public.profiles_default_perms() returns trigger
language plpgsql as $$
begin
  if new.role is distinct from old.role then new.perms := public.role_perms(new.role); end if;
  return new;
end $$;
create trigger profiles_default_perms before update of role on public.profiles
  for each row execute function public.profiles_default_perms();

update public.profiles set perms = public.role_perms(role) where role <> 'customer';

-- the owner chooses what each member can do
create or replace function public.set_member_perms(p_user uuid, p_perms text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'owner' then raise exception 'FORBIDDEN'; end if;
  if exists (select 1 from unnest(coalesce(p_perms, '{}')) x where x <> all (public.all_perms())) then raise exception 'INVALID_INPUT'; end if;
  update profiles set perms = (select coalesce(array_agg(distinct x), '{}') from unnest(coalesce(p_perms, '{}')) x)
   where id = p_user and role not in ('owner', 'customer');
  if not found then raise exception 'NOT_FOUND'; end if;
end $$;

create or replace function public.remove_member(p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'owner' then raise exception 'FORBIDDEN'; end if;
  update profiles set role = 'customer', perms = '{}', is_active = true where id = p_user and role <> 'owner';
  if not found then raise exception 'NOT_FOUND'; end if;
end $$;

-- only the owner adds / changes team members
create or replace function public.set_user_role(p_email text, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare v_target profiles;
begin
  if public.my_role() <> 'owner' then raise exception 'FORBIDDEN'; end if;
  if p_role not in ('customer','manager','support','fulfillment') then raise exception 'INVALID_INPUT'; end if;
  select * into v_target from profiles where lower(email) = lower(trim(p_email));
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_target.role = 'owner' then raise exception 'FORBIDDEN'; end if;
  update profiles set role = p_role where id = v_target.id;
  if p_role <> 'customer' then
    perform public.notify(v_target.id, 'اتضفت لفريق NŌVAKI', 'You joined the NŌVAKI team', 'اتفتحتلك صلاحيات الفريق.', 'Team access has been enabled for you.', 'team', null);
  end if;
end $$;

create or replace function public.set_member_active(p_user uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if public.my_role() <> 'owner' then raise exception 'FORBIDDEN'; end if;
  update profiles set is_active = p_active where id = p_user and role not in ('owner');
end $$;

grant execute on function public.has_perm(text) to authenticated, anon;
grant execute on function public.set_member_perms(uuid, text[]) to authenticated;
grant execute on function public.remove_member(uuid) to authenticated;
