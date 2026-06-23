-- 0002_security_functions.sql
-- Helper functions used by RLS policies and the join RPC.
--
-- These are SECURITY DEFINER so that when called from inside an RLS policy they
-- can read friendships/close_friends/events WITHOUT re-triggering RLS on those
-- tables. That avoids infinite policy recursion. They are STABLE (read-only).

-- Are a and b accepted friends? (order-independent)
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.friendships f
    where f.status = 'accepted'
      and (
        (f.requester_id = a and f.addressee_id = b)
        or (f.requester_id = b and f.addressee_id = a)
      )
  );
$$;

-- Has `owner` marked `viewer` a close friend (and are they actually friends)?
create or replace function public.is_close_friend_of(owner uuid, viewer uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.close_friends c
    where c.owner_id = owner and c.friend_id = viewer
  )
  and public.are_friends(owner, viewer);
$$;

-- Can the current user see this event under its audience rules?
create or replace function public.can_see_event(p_event_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from public.events e
    where e.id = p_event_id
      and (
        e.host_id = auth.uid()
        or (e.audience = 'friends' and public.are_friends(e.host_id, auth.uid()))
        or (e.audience = 'close_friends' and public.is_close_friend_of(e.host_id, auth.uid()))
      )
  );
$$;
