-- Owner-only app rename, confirmed with the secret code (checked against the admin account's password hash; never stored in the repo).
insert into public.app_settings(key, value) values ('brand_name', 'NŌVAKI') on conflict (key) do nothing;

alter policy settings_write on public.app_settings
  using (public.has_perm('settings_edit') and key not in ('owner_email','brand_name'))
  with check (public.has_perm('settings_edit') and key not in ('owner_email','brand_name'));

create table if not exists public.secret_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  ok boolean not null,
  at timestamptz not null default now()
);
alter table public.secret_attempts enable row level security;

create or replace function public.set_brand_name(p_name text, p_code text) returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare v_hash text; v_name text := trim(coalesce(p_name, ''));
begin
  if auth.uid() is null or public.my_role() <> 'owner' then raise exception 'FORBIDDEN'; end if;
  if (select count(*) from secret_attempts where user_id = auth.uid() and not ok and at > now() - interval '10 minutes') >= 5 then raise exception 'LOCKED'; end if;
  if length(v_name) < 2 or length(v_name) > 24 then raise exception 'INVALID_INPUT'; end if;
  select encrypted_password into v_hash from auth.users where email = 'admin@novaki.app';
  if v_hash is null or coalesce(p_code, '') = '' or extensions.crypt(p_code, v_hash) <> v_hash then
    insert into secret_attempts(user_id, ok) values (auth.uid(), false);
    raise exception 'WRONG_CODE';
  end if;
  insert into secret_attempts(user_id, ok) values (auth.uid(), true);
  insert into app_settings(key, value) values ('brand_name', v_name)
    on conflict (key) do update set value = excluded.value;
end $$;
grant execute on function public.set_brand_name(text, text) to authenticated;
alter publication supabase_realtime add table public.app_settings;
