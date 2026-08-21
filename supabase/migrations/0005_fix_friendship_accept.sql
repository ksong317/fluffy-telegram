-- 0005_fix_friendship_accept.sql
-- SECURITY FIX for the update policy created in 0003.
--
-- The original policy was symmetric:
--
--   using      (auth.uid() in (requester_id, addressee_id))
--   with check (auth.uid() in (requester_id, addressee_id))
--
-- The requester is a member of that set, so the requester could set
-- status = 'accepted' on their OWN pending request. Nothing in the API layer
-- prevents it either: FriendsService.accept() is a bare status update, and the
-- publishable key needed to make that call ships inside the app binary.
--
-- Impact: send a request to any user, immediately self-accept, and you are now
-- an 'accepted' friend of someone who never consented. events_select_visible
-- then grants read access to every 'friends'-audience event that person hosts,
-- defeating the audience dial.
--
-- Fix: WITH CHECK inspects the NEW row, so requiring auth.uid() = addressee_id
-- whenever the resulting status is 'accepted' means only the addressee can
-- perform the pending -> accepted transition. Either party may still update the
-- row otherwise (e.g. re-requesting after a removal).

drop policy if exists "friendships_update_involved" on public.friendships;

create policy "friendships_update_involved"
  on public.friendships for update
  to authenticated
  using (auth.uid() in (requester_id, addressee_id))
  with check (
    auth.uid() in (requester_id, addressee_id)
    and (status <> 'accepted' or auth.uid() = addressee_id)
  );

-- Any friendships that were already self-accepted before this fix landed are
-- indistinguishable from legitimate ones at the row level, so they are left
-- alone deliberately rather than mass-reverted. This project has no real users
-- yet; if that changes before deploying, audit accepted rows first.
