-- 0004_rpc_and_jobs.sql
-- Transactional join (race-safe capacity), event lifecycle, and storage bucket.

-- ---------- join_event ----------
-- Atomically join an event, enforcing capacity under a row lock so two people
-- can't grab the last seat. Returns the participant row. Call from the app via
-- supabase.rpc("join_event", params: ...).
create or replace function public.join_event(p_event_id uuid, p_note text default null)
returns public.event_participants
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events;
  v_count integer;
  v_row   public.event_participants;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '28000';
  end if;

  -- Lock the event row for the duration of the transaction.
  select * into v_event from public.events where id = p_event_id for update;
  if not found then
    raise exception 'Event not found' using errcode = 'P0002';
  end if;

  if not public.can_see_event(p_event_id) then
    raise exception 'Not allowed to join this event' using errcode = '42501';
  end if;
  if v_event.status <> 'open' then
    raise exception 'Event is not open' using errcode = 'P0001';
  end if;
  if now() >= v_event.closes_at then
    raise exception 'Event window has closed' using errcode = 'P0001';
  end if;

  select count(*) into v_count
  from public.event_participants
  where event_id = p_event_id;

  if v_count >= v_event.capacity then
    raise exception 'Event is full' using errcode = 'P0001';
  end if;

  insert into public.event_participants (event_id, user_id, note)
  values (p_event_id, auth.uid(), p_note)
  on conflict (event_id, user_id) do update set note = excluded.note
  returning * into v_row;

  -- Auto-close when the final seat is taken.
  if (v_count + 1) >= v_event.capacity then
    update public.events set status = 'closed' where id = p_event_id;
  end if;

  return v_row;
end;
$$;

-- ---------- leave_event ----------
create or replace function public.leave_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.event_participants
  where event_id = p_event_id and user_id = auth.uid();

  -- Re-open an event that auto-closed purely because it was full.
  update public.events e
  set status = 'open'
  where e.id = p_event_id
    and e.status = 'closed'
    and now() < e.closes_at
    and (select count(*) from public.event_participants p where p.event_id = e.id) < e.capacity;
end;
$$;

-- ---------- expire_events ----------
-- Close any open events whose window has passed. Scheduled via pg_cron below.
create or replace function public.expire_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
begin
  update public.events
  set status = 'closed'
  where status = 'open' and now() >= closes_at;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- Run expiry every minute. Requires the pg_cron extension (enable it once in the
-- dashboard: Database → Extensions → pg_cron). Safe to leave commented until then.
-- create extension if not exists pg_cron;
-- select cron.schedule('expire-events', '* * * * *', $$select public.expire_events();$$);

-- ---------- storage: profile photos ----------
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Anyone can read avatars (public bucket); users write only to their own folder
-- (avatars/{uid}/...).
create policy "avatars_public_read"
  on storage.objects for select
  using (bucket_id = 'avatars');

create policy "avatars_insert_own_folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_update_own_folder"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy "avatars_delete_own_folder"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
