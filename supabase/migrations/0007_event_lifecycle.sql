-- 0007_event_lifecycle.sql
-- Two lifecycle bugs from 0004.
--
-- 1. leave_event() re-opened ANY closed event that was under capacity and still
--    before closes_at. `status` alone can't distinguish "auto-closed because the
--    last seat went" from "the host shut it down on purpose" (EventsService
--    .setStatus lets them), so a host could cancel a ride, one person leaves,
--    and the ride is live again. Recording WHY it closed makes the two cases
--    distinguishable, and only the automatic one is reversible.
--
-- 2. expire_events() was never scheduled -- the pg_cron block at the bottom of
--    0004 was left commented out. fetchFeed() filters on closes_at client-side
--    so the feed looked correct, but status stayed 'open' forever everywhere
--    else (Activity, event detail).

alter table public.events
  add column if not exists auto_closed boolean not null default false;

comment on column public.events.auto_closed is
  'True when join_event() closed this event because it filled up. Only such a closure is reversible by leave_event().';

-- ---------- join_event: record that a closure was automatic ----------
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

  -- Auto-close when the final seat is taken, and mark it as such so that
  -- leave_event() knows this particular closure may be undone.
  if (v_count + 1) >= v_event.capacity then
    update public.events
    set status = 'closed', auto_closed = true
    where id = p_event_id;
  end if;

  return v_row;
end;
$$;

-- ---------- leave_event: only reverse an automatic closure ----------
create or replace function public.leave_event(p_event_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.event_participants
  where event_id = p_event_id and user_id = auth.uid();

  update public.events e
  set status = 'open', auto_closed = false
  where e.id = p_event_id
    and e.status = 'closed'
    and e.auto_closed                     -- the host's own closure stays closed
    and now() < e.closes_at
    and (
      select count(*) from public.event_participants p where p.event_id = e.id
    ) < e.capacity;
end;
$$;

-- ---------- expire_events: a closure by expiry is not automatic-full ----------
-- Left explicit so an expired event can never be resurrected by someone leaving.
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
  set status = 'closed', auto_closed = false
  where status = 'open' and now() >= closes_at;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

-- ---------- schedule the expiry sweep ----------
-- pg_cron may not be grantable on every plan/region, and a migration that hard
-- fails here would block everything after it. Degrade to a notice instead: the
-- worst case is that expiry doesn't run, which is exactly today's behaviour.
do $$
begin
  create extension if not exists pg_cron;

  -- Re-scheduling an existing job name raises rather than replacing it.
  perform cron.unschedule('expire-events')
  where exists (select 1 from cron.job where jobname = 'expire-events');

  perform cron.schedule(
    'expire-events',
    '* * * * *',
    $cron$select public.expire_events();$cron$
  );
  raise notice 'pg_cron scheduled: expire-events runs every minute';
exception when others then
  raise notice 'pg_cron unavailable (%), expire_events() left unscheduled. Enable pg_cron under Database -> Extensions, then re-run this block.', sqlerrm;
end;
$$;
