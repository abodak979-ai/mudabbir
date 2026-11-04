-- مُدبِّر: core schema (MVP)

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- Profile / settings (1 row per user)
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  language text not null default 'ar' check (language in ('ar','en')),
  currency text not null default 'SAR',
  numerals text not null default 'western' check (numerals in ('western','arabic')),
  payday_day smallint not null default 27 check (payday_day between 1 and 31),
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Salary plan (1 active row per user)
create table public.budget_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade default auth.uid(),
  net_salary numeric(12,2) not null default 0 check (net_salary >= 0),
  template text not null default '50_30_20' check (template in ('50_30_20','70_20_10','40_30_30','custom')),
  savings_mode text not null default 'percent' check (savings_mode in ('percent','amount')),
  savings_value numeric(12,2) not null default 0 check (savings_value >= 0),
  investment_mode text not null default 'percent' check (investment_mode in ('percent','amount')),
  investment_value numeric(12,2) not null default 0 check (investment_value >= 0),
  emergency_first boolean not null default false,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.incomes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  amount numeric(12,2) not null check (amount > 0),
  kind text not null default 'salary' check (kind in ('salary','extra')),
  source_name text,
  received_on date not null default current_date,
  allocation text not null default 'same_ratios' check (allocation in ('same_ratios','savings','spending')),
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.fixed_obligations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name text not null,
  amount numeric(12,2) not null check (amount >= 0),
  due_day smallint not null check (due_day between 1 and 31),
  kind text not null default 'bill' check (kind in ('rent','installment','bill','subscription','other')),
  remind boolean not null default true,
  last_paid_on date,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name text not null,
  icon text not null default 'category',
  color int not null default 4280391411, -- widened to bigint in 20261104022618
  monthly_limit numeric(12,2) check (monthly_limit is null or monthly_limit >= 0),
  alerts_enabled boolean not null default true,
  sort_order int not null default 0,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  amount numeric(12,2) not null check (amount > 0),
  category_id uuid references public.categories(id) on delete set null,
  spent_at timestamptz not null default now(),
  note text,
  receipt_path text,
  source text not null default 'manual' check (source in ('manual','sms','bank')),
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  name text not null,
  target_amount numeric(12,2) not null check (target_amount > 0),
  current_amount numeric(12,2) not null default 0 check (current_amount >= 0),
  target_date date,
  is_emergency boolean not null default false,
  emergency_months smallint check (emergency_months between 1 and 24),
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.investments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
  kind text not null default 'fund' check (kind in ('stocks','fund','sukuk','gold','other')),
  name text,
  invested_amount numeric(12,2) not null default 0 check (invested_amount >= 0),
  current_value numeric(12,2) not null default 0 check (current_value >= 0),
  valued_on date not null default current_date,
  deleted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- indexes for RLS + incremental sync
create index on public.incomes (user_id, updated_at);
create index on public.fixed_obligations (user_id, updated_at);
create index on public.categories (user_id, updated_at);
create index on public.expenses (user_id, updated_at);
create index on public.expenses (user_id, spent_at);
create index on public.expenses (category_id);
create index on public.savings_goals (user_id, updated_at);
create index on public.investments (user_id, updated_at);

-- updated_at triggers + RLS
do $$
declare t text;
begin
  foreach t in array array['profiles','budget_plans','incomes','fixed_obligations','categories','expenses','savings_goals','investments'] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
    execute format('alter table public.%I enable row level security', t);
  end loop;
end $$;

create policy "own profile select" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "own profile update" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "own profile insert" on public.profiles for insert to authenticated with check ((select auth.uid()) = id);

do $$
declare t text;
begin
  foreach t in array array['budget_plans','incomes','fixed_obligations','categories','expenses','savings_goals','investments'] loop
    execute format('create policy "own rows select" on public.%I for select to authenticated using ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows insert" on public.%I for insert to authenticated with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows update" on public.%I for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format('create policy "own rows delete" on public.%I for delete to authenticated using ((select auth.uid()) = user_id)', t);
  end loop;
end $$;

-- New user: profile only (default categories are created client-side so they work offline with stable ids)
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id) on conflict do nothing;
  return new;
end $$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- In-app account deletion (PDPL)
create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke execute on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;

-- Private receipts bucket, per-user folders
insert into storage.buckets (id, name, public) values ('receipts', 'receipts', false) on conflict do nothing;

create policy "own receipts read" on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own receipts write" on storage.objects for insert to authenticated
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "own receipts delete" on storage.objects for delete to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = (select auth.uid())::text);
