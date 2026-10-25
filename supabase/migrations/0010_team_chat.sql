-- Internal team chat: a general channel (everyone on the team) and private 1-to-1 threads.
create table if not exists public.team_threads (
  id uuid primary key default gen_random_uuid(),
  a uuid not null references public.profiles(id) on delete cascade,
  b uuid not null references public.profiles(id) on delete cascade,
  last_at timestamptz not null default now(),
  last_body text,
  created_at timestamptz not null default now(),
  unique (a, b),
  check (a < b)
);
create table if not exists public.team_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid references public.team_threads(id) on delete cascade,
  channel text not null default 'direct' check (channel in ('direct','general')),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (length(trim(body)) > 0 and length(body) <= 2000),
  created_at timestamptz not null default now(),
  constraint team_messages_chan_ok check ((channel = 'general' and thread_id is null) or (channel = 'direct' and thread_id is not null))
);
create index if not exists team_messages_thread_idx on public.team_messages(thread_id, created_at);
alter table public.team_threads enable row level security;
alter table public.team_messages enable row level security;
create policy team_threads_read on public.team_threads for select to authenticated using (public.is_staff() and auth.uid() in (a, b));
create policy team_messages_read on public.team_messages for select to authenticated
  using (public.is_staff() and (channel = 'general' or exists (select 1 from public.team_threads t where t.id = thread_id and auth.uid() in (t.a, t.b))));
create policy team_messages_send on public.team_messages for insert to authenticated
  with check (public.is_staff() and sender_id = auth.uid() and (
    (channel = 'general' and thread_id is null)
    or (channel = 'direct' and exists (select 1 from public.team_threads t where t.id = thread_id and auth.uid() in (t.a, t.b)))));
alter publication supabase_realtime add table public.team_messages;
alter publication supabase_realtime add table public.team_threads;

create or replace function public.open_team_thread(p_peer uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := auth.uid(); v_a uuid; v_b uuid; v_id uuid;
begin
  if not public.is_staff() then raise exception 'FORBIDDEN'; end if;
  if p_peer is null or p_peer = v_me then raise exception 'INVALID_INPUT'; end if;
  if not exists (select 1 from profiles where id = p_peer and is_active and role <> 'customer') then raise exception 'INVALID_INPUT'; end if;
  v_a := least(v_me, p_peer); v_b := greatest(v_me, p_peer);
  insert into team_threads(a, b) values (v_a, v_b) on conflict (a, b) do nothing;
  select id into v_id from team_threads where a = v_a and b = v_b;
  return v_id;
end $$;

create or replace function public.team_message_after() returns trigger
language plpgsql security definer set search_path = public as $$
declare t team_threads; v_peer uuid; v_name text;
begin
  select full_name into v_name from profiles where id = new.sender_id;
  if new.channel = 'general' then
    insert into notifications(user_id, title_ar, title_en, body_ar, body_en, kind, ref_id)
    select id, 'محادثة الفريق · ' || coalesce(v_name, ''), 'Team chat · ' || coalesce(v_name, ''), left(new.body, 140), left(new.body, 140), 'team_chat', null
      from profiles where is_active and role <> 'customer' and id <> new.sender_id;
    return null;
  end if;
  select * into t from team_threads where id = new.thread_id;
  update team_threads set last_at = new.created_at, last_body = left(new.body, 120) where id = new.thread_id;
  v_peer := case when t.a = new.sender_id then t.b else t.a end;
  perform public.notify(v_peer, 'رسالة من ' || coalesce(v_name, 'الفريق'), 'Message from ' || coalesce(v_name, 'the team'),
    left(new.body, 140), left(new.body, 140), 'team_chat', new.thread_id);
  return null;
end $$;
create trigger team_message_after after insert on public.team_messages for each row execute function public.team_message_after();

create or replace function public.list_team() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_staff() then raise exception 'FORBIDDEN'; end if;
  return coalesce((select jsonb_agg(m) from (
    select id, full_name, role, phone, (coalesce(online_at, 'epoch') > now() - interval '10 minutes') as online
      from profiles where is_active and role <> 'customer' and id <> auth.uid() order by full_name) m), '[]'::jsonb);
end $$;
grant execute on function public.open_team_thread(uuid) to authenticated;
grant execute on function public.list_team() to authenticated;
