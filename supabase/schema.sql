-- OMG WARSAUCE · schema del database (Supabase > SQL Editor > New query > incolla tutto > Run)
-- Pronto da eseguire cosi com'e. In fondo c'e la riga per aggiungere Giovanni come admin.

create table if not exists public.guests (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  instagram text check (instagram is null or instagram ~ '^[A-Za-z0-9._]{1,30}$'),
  bio text check (bio is null or char_length(bio) <= 140),
  photo_url text,
  is_host boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.dinners (
  id bigint generated always as identity primary key,
  number int not null,
  starts_at timestamptz,
  kind text not null default 'pasta' check (kind in ('pasta','pizza','mixed')),
  seats int not null default 20 check (seats between 1 and 60),
  dishes text[] not null default '{}',
  status text not null default 'open' check (status in ('open','closed','done')),
  created_at timestamptz not null default now()
);

create table if not exists public.bookings (
  id bigint generated always as identity primary key,
  dinner_id bigint not null references public.dinners(id) on delete cascade,
  guest_id uuid not null references public.guests(id) on delete cascade,
  main text not null,
  side text,
  drink text,
  plus int not null default 0 check (plus between 0 and 2),
  notes text check (notes is null or char_length(notes) <= 140),
  attended boolean not null default true,
  created_at timestamptz not null default now(),
  unique (dinner_id, guest_id)
);

create table if not exists public.admins (email text primary key);

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
grant execute on function public.is_admin() to anon, authenticated;

-- Solo gli admin possono decidere chi e "Host"
create or replace function public.protect_host() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then
    if tg_op = 'INSERT' then new.is_host := false; else new.is_host := old.is_host; end if;
  end if;
  return new;
end $$;
drop trigger if exists guests_protect_host on public.guests;
create trigger guests_protect_host before insert or update on public.guests
for each row execute function public.protect_host();

-- Niente overbooking
create or replace function public.check_seats() returns trigger
language plpgsql security definer set search_path = public as $$
declare cap int; used int;
begin
  select seats into cap from public.dinners where id = new.dinner_id;
  select coalesce(sum(1 + plus), 0) into used from public.bookings
    where dinner_id = new.dinner_id and id is distinct from new.id;
  if used + 1 + new.plus > cap then raise exception 'Sold out'; end if;
  return new;
end $$;
drop trigger if exists bookings_seats on public.bookings;
create trigger bookings_seats before insert or update of plus, dinner_id on public.bookings
for each row execute function public.check_seats();

alter table public.guests enable row level security;
alter table public.dinners enable row level security;
alter table public.bookings enable row level security;
alter table public.admins enable row level security;

-- guests
drop policy if exists "guests read" on public.guests;
create policy "guests read" on public.guests for select using (true);
drop policy if exists "guests insert own" on public.guests;
create policy "guests insert own" on public.guests for insert to authenticated with check (auth.uid() = id);
drop policy if exists "guests update own" on public.guests;
create policy "guests update own" on public.guests for update to authenticated using (auth.uid() = id or public.is_admin()) with check (auth.uid() = id or public.is_admin());
drop policy if exists "guests delete admin" on public.guests;
create policy "guests delete admin" on public.guests for delete to authenticated using (public.is_admin());

-- dinners
drop policy if exists "dinners read" on public.dinners;
create policy "dinners read" on public.dinners for select using (true);
drop policy if exists "dinners admin" on public.dinners;
create policy "dinners admin" on public.dinners for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- bookings
drop policy if exists "bookings read" on public.bookings;
create policy "bookings read" on public.bookings for select using (true);
drop policy if exists "bookings insert own" on public.bookings;
create policy "bookings insert own" on public.bookings for insert to authenticated
  with check (auth.uid() = guest_id and attended = true and exists (select 1 from public.dinners d where d.id = dinner_id and d.status = 'open'));
drop policy if exists "bookings update own" on public.bookings;
create policy "bookings update own" on public.bookings for update to authenticated
  using ((auth.uid() = guest_id and exists (select 1 from public.dinners d where d.id = dinner_id and d.status = 'open')) or public.is_admin())
  with check ((auth.uid() = guest_id and attended = true and exists (select 1 from public.dinners d where d.id = dinner_id and d.status = 'open')) or public.is_admin());
drop policy if exists "bookings delete own" on public.bookings;
create policy "bookings delete own" on public.bookings for delete to authenticated
  using ((auth.uid() = guest_id and exists (select 1 from public.dinners d where d.id = dinner_id and d.status = 'open')) or public.is_admin());

-- foto profilo
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true) on conflict (id) do nothing;
drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects for select using (bucket_id = 'avatars');
drop policy if exists "avatars insert own" on storage.objects;
create policy "avatars insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars update own" on storage.objects;
create policy "avatars update own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars delete own or admin" on storage.objects;
create policy "avatars delete own or admin" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- foto delle cene: le caricano gli invitati, le pubblicano solo gli admin
create table if not exists public.photos (
  id bigint generated always as identity primary key,
  dinner_id bigint not null references public.dinners(id) on delete cascade,
  guest_id uuid not null references public.guests(id) on delete cascade,
  url text not null,
  path text not null,
  status text not null default 'pending' check (status in ('pending','approved')),
  created_at timestamptz not null default now()
);
alter table public.photos enable row level security;
drop policy if exists "photos read" on public.photos;
create policy "photos read" on public.photos for select
  using (status = 'approved' or auth.uid() = guest_id or public.is_admin());
drop policy if exists "photos insert own" on public.photos;
create policy "photos insert own" on public.photos for insert to authenticated
  with check (auth.uid() = guest_id and status = 'pending'
    and (public.is_admin() or exists (select 1 from public.bookings b where b.dinner_id = photos.dinner_id and b.guest_id = auth.uid())));
drop policy if exists "photos admin update" on public.photos;
create policy "photos admin update" on public.photos for update to authenticated
  using (public.is_admin()) with check (public.is_admin());
drop policy if exists "photos delete" on public.photos;
create policy "photos delete" on public.photos for delete to authenticated
  using ((auth.uid() = guest_id and status = 'pending') or public.is_admin());

insert into storage.buckets (id, name, public) values ('dinner-photos', 'dinner-photos', true) on conflict (id) do nothing;
drop policy if exists "dinner photos read" on storage.objects;
create policy "dinner photos read" on storage.objects for select using (bucket_id = 'dinner-photos');
drop policy if exists "dinner photos insert own" on storage.objects;
create policy "dinner photos insert own" on storage.objects for insert to authenticated
  with check (bucket_id = 'dinner-photos' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "dinner photos delete" on storage.objects;
create policy "dinner photos delete" on storage.objects for delete to authenticated
  using (bucket_id = 'dinner-photos' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));

-- aggiornamenti in tempo reale (chi viene stasera si aggiorna da solo)
do $$ begin
  begin alter publication supabase_realtime add table public.bookings; exception when others then null; end;
  begin alter publication supabase_realtime add table public.guests; exception when others then null; end;
  begin alter publication supabase_realtime add table public.dinners; exception when others then null; end;
  begin alter publication supabase_realtime add table public.photos; exception when others then null; end;
end $$;

-- ADMIN: chi puo entrare nella Chef area
insert into public.admins (email) values
  ('matteotrinchero02@gmail.com')
on conflict do nothing;

-- Per aggiungere Giovanni piu avanti: togli i due trattini all'inizio della riga sotto, metti la sua email ed esegui solo quella riga.
-- insert into public.admins (email) values ('email.di.giovanni@esempio.com') on conflict do nothing;
