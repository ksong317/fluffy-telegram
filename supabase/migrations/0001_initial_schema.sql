-- 0001_initial_schema.sql
-- Core tables for Shotgun. See section 7 of the product spec.
--
-- Model notes:
--   * Friendship is mutual: one `friendships` row per pair, status pending|accepted.
--   * "Close friend" is a DIRECTIONAL label the owner applies, so it lives in its
--     own `close_friends` table (owner_id -> friend_id) rather than a flag on the
--     mutual friendship row. This makes the audience RLS check unambiguous.

-- ---------- Enums ----------
create type friendship_status as enum ('pending', 'accepted');
create type event_audience    as enum ('close_friends', 'friends');
create type money_type        as enum ('free', 'chip_in', 'set_price');
create type event_status      as enum ('open', 'closed', 'cancelled');

-- ---------- profiles ----------
-- One row per auth user. Created automatically on signup (see trigger below),
-- then completed by the profile-setup screen.
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text not null default '',
  photo_url     text,
  venmo_handle  text,
  created_at    timestamptz not null default now()
);

comment on table public.profiles is 'Public-facing user profile, 1:1 with auth.users.';

-- ---------- friendships ----------
create table public.friendships (
  id            uuid primary key default gen_random_uuid(),
  requester_id  uuid not null references public.profiles (id) on delete cascade,
  addressee_id  uuid not null references public.profiles (id) on delete cascade,
  status        friendship_status not null default 'pending',
  created_at    timestamptz not null default now(),
  -- No self-friendship.
  constraint friendship_distinct check (requester_id <> addressee_id)
);

-- One relationship per unordered pair (least/greatest normalizes direction).
-- Expression uniqueness must be a unique index, not a UNIQUE table constraint.
create unique index friendship_unique_pair
  on public.friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));

create index friendships_requester_idx on public.friendships (requester_id);
create index friendships_addressee_idx on public.friendships (addressee_id);

-- ---------- close_friends ----------
-- Directional: owner_id has labelled friend_id a "close friend".
create table public.close_friends (
  owner_id    uuid not null references public.profiles (id) on delete cascade,
  friend_id   uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (owner_id, friend_id),
  constraint close_friend_distinct check (owner_id <> friend_id)
);

create index close_friends_owner_idx on public.close_friends (owner_id);

-- ---------- events ----------
create table public.events (
  id          uuid primary key default gen_random_uuid(),
  host_id     uuid not null references public.profiles (id) on delete cascade,
  title       text not null,
  place_text  text not null,
  starts_at   timestamptz not null,
  closes_at   timestamptz not null,
  capacity    integer not null,
  audience    event_audience not null default 'close_friends',
  money_type  money_type not null default 'free',
  amount      numeric(10, 2),               -- nullable; required only for chip_in / set_price
  note        text,
  status      event_status not null default 'open',
  created_at  timestamptz not null default now(),
  constraint capacity_positive check (capacity > 0),
  constraint window_valid check (closes_at > starts_at),
  constraint amount_sign check (amount is null or amount >= 0),
  -- A priced event needs an amount; a free one must not carry one.
  constraint amount_matches_money_type check (
    (money_type = 'free' and amount is null)
    or (money_type in ('chip_in', 'set_price') and amount is not null)
  )
);

create index events_status_closes_idx on public.events (status, closes_at);
create index events_host_idx on public.events (host_id);

-- ---------- event_participants ----------
create table public.event_participants (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  note       text,
  paid       boolean not null default false,
  joined_at  timestamptz not null default now(),
  constraint participant_unique unique (event_id, user_id)
);

create index event_participants_event_idx on public.event_participants (event_id);
create index event_participants_user_idx on public.event_participants (user_id);

-- ---------- new-user trigger ----------
-- Create a stub profile whenever an auth user is created so foreign keys to
-- profiles always resolve. The app fills in display_name / venmo during setup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'display_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
