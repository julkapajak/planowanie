-- Planowanie: baza dla kont. Wklej całość w Supabase → SQL Editor → Run.
-- Każdy użytkownik ma jeden wiersz z całym planem i widzi wyłącznie swój.

create table if not exists public.plans (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.plans enable row level security;

drop policy if exists "plans: odczyt własnego" on public.plans;
drop policy if exists "plans: dodanie własnego" on public.plans;
drop policy if exists "plans: zmiana własnego" on public.plans;
drop policy if exists "plans: usunięcie własnego" on public.plans;

create policy "plans: odczyt własnego" on public.plans
  for select using (auth.uid() = user_id);
create policy "plans: dodanie własnego" on public.plans
  for insert with check (auth.uid() = user_id);
create policy "plans: zmiana własnego" on public.plans
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "plans: usunięcie własnego" on public.plans
  for delete using (auth.uid() = user_id);

-- czas zapisu zawsze z serwera (porównujemy go między urządzeniami)
create or replace function public.plans_touch() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists plans_touch on public.plans;
create trigger plans_touch before insert or update on public.plans
  for each row execute function public.plans_touch();
