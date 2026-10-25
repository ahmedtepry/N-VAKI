-- NŌVAKI core schema: profiles/roles, catalog, orders, notifications, support chat, RLS.

create table if not exists public.app_settings (
  key text primary key,
  value text not null
);
insert into public.app_settings(key, value) values
  ('owner_email', 'ahmedtepry@gmail.com'),
  ('brand_name', 'NŌVAKI'),
  ('currency', 'EGP'),
  ('shipping_fee', '60'),
  ('free_shipping_over', '1500'),
  ('support_hours_ar', 'يوميًا من 10 ص حتى 10 م'),
  ('support_hours_en', 'Daily 10am – 10pm')
on conflict (key) do nothing;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text not null default '',
  phone text,
  avatar_url text,
  role text not null default 'customer' check (role in ('customer','owner','manager','support','fulfillment')),
  is_active boolean not null default true,
  online_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select coalesce((select role from profiles where id = auth.uid() and is_active), 'anon')
$$;
create or replace function public.has_role(p_roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() = any(p_roles)
$$;
create or replace function public.is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select public.my_role() in ('owner','manager','support','fulfillment')
$$;

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_owner text; v_role text := 'customer';
begin
  select lower(value) into v_owner from app_settings where key = 'owner_email';
  if v_owner is not null and lower(new.email) = v_owner then v_role := 'owner'; end if;
  insert into profiles(id, email, full_name, phone, role)
  values (new.id, new.email,
          coalesce(nullif(trim(new.raw_user_meta_data->>'full_name'), ''), split_part(new.email, '@', 1)),
          nullif(trim(new.raw_user_meta_data->>'phone'), ''),
          v_role)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Catalog -------------------------------------------------------------------
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_en text not null,
  description_ar text not null default '',
  description_en text not null default '',
  price numeric(10,2) not null check (price >= 0),
  compare_at_price numeric(10,2),
  category text not null default 'tees',
  garment text not null default 'tee' check (garment in ('tee','hoodie','jacket','jersey','shirt')),
  image_url text,
  active boolean not null default true,
  featured boolean not null default false,
  sort int not null default 100,
  created_at timestamptz not null default now()
);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  color_name_ar text not null,
  color_name_en text not null,
  color_hex text not null check (color_hex ~ '^#[0-9A-Fa-f]{6}$'),
  accent_hex text check (accent_hex is null or accent_hex ~ '^#[0-9A-Fa-f]{6}$'),
  image_url text,
  size text not null,
  stock int not null default 0 check (stock >= 0),
  unique (product_id, color_hex, size)
);
create index if not exists product_variants_product_idx on public.product_variants(product_id);

-- Orders --------------------------------------------------------------------
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  order_no bigint generated always as identity (start with 1001),
  customer_id uuid not null references auth.users(id),
  status text not null default 'new' check (status in ('new','confirmed','packed','shipped','delivered','cancelled')),
  subtotal numeric(10,2) not null default 0,
  shipping_fee numeric(10,2) not null default 0,
  total numeric(10,2) not null default 0,
  payment_method text not null default 'cod',
  customer_name text not null,
  phone text not null,
  address text not null,
  city text not null default '',
  notes text,
  assigned_to uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_customer_idx on public.orders(customer_id, created_at desc);
create index if not exists orders_status_idx on public.orders(status, created_at desc);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,
  name_ar text not null,
  name_en text not null,
  color_name_ar text not null,
  color_name_en text not null,
  color_hex text not null,
  garment text not null default 'tee',
  size text not null,
  unit_price numeric(10,2) not null,
  qty int not null check (qty > 0)
);
create index if not exists order_items_order_idx on public.order_items(order_id);

create table if not exists public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  note text,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists order_hist_idx on public.order_status_history(order_id, created_at);

-- Notifications ---------------------------------------------------------------
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title_ar text not null,
  title_en text not null,
  body_ar text not null default '',
  body_en text not null default '',
  kind text not null default 'info',
  ref_id uuid,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);

-- Support chat ----------------------------------------------------------------
create table if not exists public.support_conversations (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  subject text,
  order_id uuid references public.orders(id) on delete set null,
  status text not null default 'open' check (status in ('open','closed')),
  assigned_to uuid references public.profiles(id),
  agent_name text,
  customer_unread int not null default 0,
  staff_unread int not null default 0,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create unique index if not exists one_open_conv_per_customer
  on public.support_conversations(customer_id) where status = 'open';
create index if not exists support_conv_assigned_idx on public.support_conversations(assigned_to, status);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.support_conversations(id) on delete cascade,
  sender_id uuid references auth.users(id),
  sender_kind text not null check (sender_kind in ('customer','staff','bot')),
  body text not null check (length(trim(body)) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists support_msg_conv_idx on public.support_messages(conversation_id, created_at);

-- RLS -------------------------------------------------------------------------
alter table public.app_settings enable row level security;
alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.product_variants enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.notifications enable row level security;
alter table public.support_conversations enable row level security;
alter table public.support_messages enable row level security;

create policy settings_read on public.app_settings for select using (key <> 'owner_email');

create policy profiles_self_read on public.profiles for select to authenticated using (id = auth.uid() or public.is_staff());
create policy profiles_self_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
revoke update on public.profiles from authenticated, anon;
grant update (full_name, phone, avatar_url) on public.profiles to authenticated;

create policy products_read on public.products for select using (active or public.has_role(array['owner','manager']));
create policy products_write on public.products for all to authenticated
  using (public.has_role(array['owner','manager'])) with check (public.has_role(array['owner','manager']));
create policy variants_read on public.product_variants for select using (true);
create policy variants_write on public.product_variants for all to authenticated
  using (public.has_role(array['owner','manager'])) with check (public.has_role(array['owner','manager']));

create policy orders_read on public.orders for select to authenticated using (customer_id = auth.uid() or public.is_staff());
create policy order_items_read on public.order_items for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_staff())));
create policy order_hist_read on public.order_status_history for select to authenticated using (
  exists (select 1 from public.orders o where o.id = order_id and (o.customer_id = auth.uid() or public.is_staff())));

create policy notif_read on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_delete on public.notifications for delete to authenticated using (user_id = auth.uid());

create policy conv_read on public.support_conversations for select to authenticated
  using (customer_id = auth.uid() or public.has_role(array['owner','manager','support']));
create policy msg_read on public.support_messages for select to authenticated using (
  exists (select 1 from public.support_conversations c where c.id = conversation_id
          and (c.customer_id = auth.uid() or public.has_role(array['owner','manager','support']))));
create policy msg_insert_customer on public.support_messages for insert to authenticated with check (
  sender_kind = 'customer' and sender_id = auth.uid()
  and exists (select 1 from public.support_conversations c where c.id = conversation_id and c.customer_id = auth.uid() and c.status = 'open'));
create policy msg_insert_staff on public.support_messages for insert to authenticated with check (
  sender_kind = 'staff' and sender_id = auth.uid() and public.has_role(array['owner','manager','support'])
  and exists (select 1 from public.support_conversations c where c.id = conversation_id and c.status = 'open'));

-- Storage: public product images, written by owner/manager --------------------
insert into storage.buckets(id, name, public) values ('novaki-products', 'novaki-products', true) on conflict (id) do nothing;
create policy novaki_pi_read on storage.objects for select using (bucket_id = 'novaki-products');
create policy novaki_pi_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'novaki-products' and public.has_role(array['owner','manager']));
create policy novaki_pi_update on storage.objects for update to authenticated
  using (bucket_id = 'novaki-products' and public.has_role(array['owner','manager']));
create policy novaki_pi_delete on storage.objects for delete to authenticated
  using (bucket_id = 'novaki-products' and public.has_role(array['owner','manager']));

-- Realtime ----------------------------------------------------------------------
do $$ begin
  begin alter publication supabase_realtime add table public.support_messages; exception when others then null; end;
  begin alter publication supabase_realtime add table public.support_conversations; exception when others then null; end;
  begin alter publication supabase_realtime add table public.orders; exception when others then null; end;
  begin alter publication supabase_realtime add table public.notifications; exception when others then null; end;
end $$;
