-- Editable categories, sizes, coupons and store settings.

create table if not exists public.categories (
  slug text primary key check (slug ~ '^[a-z0-9_-]{2,30}$'),
  name_ar text not null,
  name_en text not null,
  sort int not null default 100,
  active boolean not null default true
);
insert into public.categories(slug, name_ar, name_en, sort) values
  ('tees', 'تيشيرتات', 'Tees', 10), ('jerseys', 'جيرسي', 'Jerseys', 20), ('hoodies', 'هوديز', 'Hoodies', 30),
  ('jackets', 'جاكيتات', 'Jackets', 40), ('shirts', 'قمصان', 'Shirts', 50)
on conflict (slug) do nothing;

create table if not exists public.size_options (
  code text primary key check (length(code) between 1 and 8),
  sort int not null default 100,
  active boolean not null default true
);
insert into public.size_options(code, sort) values ('XS',10),('S',20),('M',30),('L',40),('XL',50),('XXL',60),('3XL',70)
on conflict (code) do nothing;

create table if not exists public.coupons (
  code text primary key check (code = upper(code) and length(code) between 3 and 20),
  kind text not null check (kind in ('percent','fixed')),
  value numeric(10,2) not null check (value > 0),
  min_order numeric(10,2) not null default 0,
  max_uses int not null default 0,
  used int not null default 0,
  expires_at timestamptz,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.orders add column if not exists discount numeric(10,2) not null default 0;
alter table public.orders add column if not exists coupon_code text;

insert into public.app_settings(key, value) values
  ('store_open', 'true'),
  ('ticker_ar', 'شحن مجاني للطلبات الكبيرة|الدفع عند الاستلام|تشكيلة جديدة|خدمة عملاء مباشرة'),
  ('ticker_en', 'FREE SHIPPING ON BIG ORDERS|CASH ON DELIVERY|NEW DROP|LIVE SUPPORT')
on conflict (key) do nothing;

alter table public.categories enable row level security;
alter table public.size_options enable row level security;
alter table public.coupons enable row level security;

create policy categories_read on public.categories for select using (active or public.has_perm('categories_edit') or public.has_perm('catalog_edit'));
create policy categories_write on public.categories for all to authenticated
  using (public.has_perm('categories_edit')) with check (public.has_perm('categories_edit'));
create policy sizes_read on public.size_options for select using (active or public.has_perm('sizes_edit') or public.has_perm('catalog_edit') or public.has_perm('stock_edit'));
create policy sizes_write on public.size_options for all to authenticated
  using (public.has_perm('sizes_edit')) with check (public.has_perm('sizes_edit'));
create policy coupons_staff on public.coupons for all to authenticated
  using (public.has_perm('coupons_edit')) with check (public.has_perm('coupons_edit'));
create policy settings_write on public.app_settings for all to authenticated
  using (public.has_perm('settings_edit') and key <> 'owner_email') with check (public.has_perm('settings_edit') and key <> 'owner_email');

-- a category / size that products still use cannot be deleted
create or replace function public.guard_category_in_use() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from products where category = old.slug) then raise exception 'IN_USE'; end if;
  return old;
end $$;
create trigger categories_in_use before delete on public.categories
  for each row execute function public.guard_category_in_use();

create or replace function public.guard_size_in_use() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from product_variants where size = old.code) then raise exception 'IN_USE'; end if;
  return old;
end $$;
create trigger sizes_in_use before delete on public.size_options
  for each row execute function public.guard_size_in_use();
