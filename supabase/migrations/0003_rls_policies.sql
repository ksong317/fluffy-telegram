-- 0003_rls_policies.sql
-- Row-Level Security. The privacy model IS the product (spec §7), so RLS is the
-- last line of defence: a user can never SELECT an event they aren't allowed to.

alter table public.profiles           enable row level security;
alter table public.friendships        enable row level security;
alter table public.close_friends      enable row level security;
alter table public.events             enable row level security;
alter table public.event_participants enable row level security;

-- ---------- profiles ----------
-- Any signed-in user can read profiles (needed to search for / display friends).
create policy "profiles_select_authenticated"
  on public.profiles for select
  to authenticated
  using (true);

create policy "profiles_insert_self"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ---------- friendships ----------
-- Visible to either party.
create policy "friendships_select_involved"
  on public.friendships for select
  to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- You can only create a request as the requester.
create policy "friendships_insert_as_requester"
  on public.friendships for insert
  to authenticated
  with check (auth.uid() = requester_id);

-- Either party can update (addressee accepts/declines; either can re-request).
create policy "friendships_update_involved"
  on public.friendships for update
  to authenticated
  using (auth.uid() in (requester_id, addressee_id))
  with check (auth.uid() in (requester_id, addressee_id));

-- Either party can remove the friendship.
create policy "friendships_delete_involved"
  on public.friendships for delete
  to authenticated
  using (auth.uid() in (requester_id, addressee_id));

-- ---------- close_friends ----------
-- You manage only your own close-friends list.
create policy "close_friends_select_owner"
  on public.close_friends for select
  to authenticated
  using (auth.uid() = owner_id);

create policy "close_friends_insert_owner"
  on public.close_friends for insert
  to authenticated
  with check (auth.uid() = owner_id and public.are_friends(owner_id, friend_id));

create policy "close_friends_delete_owner"
  on public.close_friends for delete
  to authenticated
  using (auth.uid() = owner_id);

-- ---------- events ----------
-- The audience dial, enforced in the database.
create policy "events_select_visible"
  on public.events for select
  to authenticated
  using (
    host_id = auth.uid()
    or (audience = 'friends' and public.are_friends(host_id, auth.uid()))
    or (audience = 'close_friends' and public.is_close_friend_of(host_id, auth.uid()))
  );

create policy "events_insert_as_host"
  on public.events for insert
  to authenticated
  with check (host_id = auth.uid());

create policy "events_update_host"
  on public.events for update
  to authenticated
  using (host_id = auth.uid())
  with check (host_id = auth.uid());

create policy "events_delete_host"
  on public.events for delete
  to authenticated
  using (host_id = auth.uid());

-- ---------- event_participants ----------
-- Visible to the host of the event and to anyone allowed to see the event
-- (so the participant list renders in event detail).
create policy "participants_select_visible"
  on public.event_participants for select
  to authenticated
  using (public.can_see_event(event_id));

-- Direct self-join is allowed at the RLS layer, but capacity is only safe via
-- the join_event() RPC (migration 0004). Prefer the RPC in the app.
create policy "participants_insert_self"
  on public.event_participants for insert
  to authenticated
  with check (user_id = auth.uid() and public.can_see_event(event_id));

-- A joiner can update their own row (e.g. mark paid, edit note).
create policy "participants_update_self"
  on public.event_participants for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- A joiner can leave; the host can remove anyone from their event.
create policy "participants_delete_self_or_host"
  on public.event_participants for delete
  to authenticated
  using (
    user_id = auth.uid()
    or exists (
      select 1 from public.events e
      where e.id = event_id and e.host_id = auth.uid()
    )
  );
