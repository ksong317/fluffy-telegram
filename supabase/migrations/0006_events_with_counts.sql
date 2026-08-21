-- 0006_events_with_counts.sql
-- Give the feed a participant count.
--
-- fetchFeed() selects from `events` alone, which carries no notion of how many
-- people have joined, so the feed card had nothing to show but `capacity` --
-- every row read "3 spots" whether three seats were free or the ride was full.
-- Event detail got it right only because it issues a second query for
-- participants, which the feed can't afford once per row.
--
-- A view keeps the count on the same round trip. `security_invoker = true`
-- (Postgres 15+; this project is on 17) makes the view execute as the querying
-- user rather than as its owner, so events_select_visible still decides which
-- rows come back. Without that flag a view is a hole straight through RLS.

create or replace view public.events_with_counts
with (security_invoker = true) as
select
  e.*,
  (
    select count(*)
    from public.event_participants p
    where p.event_id = e.id
  )::int as participant_count
from public.events e;

comment on view public.events_with_counts is
  'events plus a joined-participant count, for the feed. Respects RLS via security_invoker.';
