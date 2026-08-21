#!/usr/bin/env python3
"""End-to-end RLS tests against a live Supabase project.

These exercise the privacy model the way an attacker would: with nothing but the
publishable key that ships inside the app binary, and raw REST calls that ignore
whatever the UI does or doesn't offer. Passing here is the only real evidence
that a policy holds -- reading the SQL is not.

Creates throwaway users (email `rlstest+<uuid>@example.com`). Requires signup to
be open and email confirmation off, which is this project's current dev setup.

    python3 scripts/rls_test.py

Reads SUPABASE_URL / SUPABASE_ANON_KEY from Config/Secrets.xcconfig.
"""

import json
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SECRETS = ROOT / "Config" / "Secrets.xcconfig"

PASSWORD = "rls-test-password-123"


def load_config():
    if not SECRETS.exists():
        sys.exit(f"missing {SECRETS}")
    text = SECRETS.read_text()

    def value(key):
        m = re.search(rf"^{key}\s*=\s*(.+)$", text, re.M)
        if not m:
            sys.exit(f"{key} not found in {SECRETS}")
        # xcconfig escapes the // in https:// as `https:/$()/`
        return m.group(1).strip().replace("$()", "")

    return value("SUPABASE_URL").rstrip("/"), value("SUPABASE_ANON_KEY")


URL, KEY = load_config()


def request(method, path, token=None, body=None, prefer=None):
    """Returns (status, parsed_body). Never raises on HTTP errors -- a 401 or a
    403 is frequently the expected result here, not a failure."""
    headers = {"apikey": KEY, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if prefer:
        headers["Prefer"] = prefer
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read().decode()
            return resp.status, (json.loads(raw) if raw else None)
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, raw


def make_user(label):
    email = f"rlstest+{uuid.uuid4().hex[:12]}@example.com"
    status, body = request("POST", "/auth/v1/signup", body={"email": email, "password": PASSWORD})
    if status >= 400 or not body:
        sys.exit(f"could not create {label}: {status} {body}")
    token = body.get("access_token")
    user = body.get("user") or {}
    if not token:
        sys.exit(
            f"signup for {label} returned no session ({status}). "
            "Email confirmation is probably still switched on."
        )
    print(f"  created {label}: {email}")
    return {"label": label, "email": email, "token": token, "id": user.get("id")}


RESULTS = []


def check(name, passed, detail=""):
    RESULTS.append((name, passed, detail))
    print(f"  {'PASS' if passed else 'FAIL'}  {name}")
    if detail and not passed:
        print(f"        {detail}")


def main():
    print(f"Project: {URL}\n")

    print("Creating test users...")
    alice = make_user("alice")
    bob = make_user("bob")
    mallory = make_user("mallory")
    print()

    # Every user needs a usable profile; the handle_new_user trigger makes a stub
    # with an empty display_name.
    for u in (alice, bob, mallory):
        request(
            "PATCH",
            f"/rest/v1/profiles?id=eq.{u['id']}",
            token=u["token"],
            body={"display_name": u["label"].title()},
        )

    print("Anonymous access")
    status, body = request("GET", "/rest/v1/events?select=id")
    check("anon cannot read events", body == [], f"got {status} {body}")
    status, body = request("GET", "/rest/v1/profiles?select=id")
    check("anon cannot read profiles", body == [], f"got {status} {body}")
    print()

    print("Friendship acceptance (migration 0005)")
    # Mallory sends Alice a request she never asked for.
    status, body = request(
        "POST",
        "/rest/v1/friendships",
        token=mallory["token"],
        body={"requester_id": mallory["id"], "addressee_id": alice["id"]},
        prefer="return=representation",
    )
    if status >= 400 or not body:
        sys.exit(f"could not create friendship row: {status} {body}")
    fid = body[0]["id"]

    # THE ATTACK: the requester accepts their own request.
    status, body = request(
        "PATCH",
        f"/rest/v1/friendships?id=eq.{fid}",
        token=mallory["token"],
        body={"status": "accepted"},
        prefer="return=representation",
    )
    self_accepted = bool(body) and isinstance(body, list) and body[0].get("status") == "accepted"
    check(
        "requester cannot accept their own request",
        not self_accepted,
        f"SELF-ACCEPT SUCCEEDED -- migration 0005 is not in effect. {status} {body}",
    )

    # The legitimate path must still work.
    status, body = request(
        "PATCH",
        f"/rest/v1/friendships?id=eq.{fid}",
        token=alice["token"],
        body={"status": "accepted"},
        prefer="return=representation",
    )
    accepted = bool(body) and isinstance(body, list) and body[0].get("status") == "accepted"
    check("addressee can accept", accepted, f"got {status} {body}")
    print()

    print("Event audience")
    # Bob hosts a friends-only event. Nobody is his friend.
    status, body = request(
        "POST",
        "/rest/v1/events",
        token=bob["token"],
        body={
            "host_id": bob["id"],
            "title": "Bob's private run",
            "place_text": "Somewhere",
            "starts_at": "2030-01-01T00:00:00Z",
            "closes_at": "2030-01-02T00:00:00Z",
            "capacity": 2,
            "audience": "friends",
            "money_type": "free",
        },
        prefer="return=representation",
    )
    if status >= 400 or not body:
        sys.exit(f"could not create event: {status} {body}")
    eid = body[0]["id"]

    status, body = request("GET", f"/rest/v1/events?id=eq.{eid}&select=id", token=bob["token"])
    check("host sees own event", body == [{"id": eid}], f"got {status} {body}")

    status, body = request("GET", f"/rest/v1/events?id=eq.{eid}&select=id", token=mallory["token"])
    check("non-friend cannot see friends-only event", body == [], f"got {status} {body}")

    # Mallory is 'accepted' friends with Alice, not Bob -- friendship must not be
    # transitive.
    status, body = request("GET", f"/rest/v1/events?id=eq.{eid}&select=id", token=alice["token"])
    check("friend-of-nobody cannot see it either", body == [], f"got {status} {body}")

    # Joining an invisible event must fail even via the RPC.
    status, body = request(
        "POST", "/rest/v1/rpc/join_event", token=mallory["token"], body={"p_event_id": eid}
    )
    check("cannot join an invisible event", status >= 400, f"got {status} {body}")
    print()

    print("Event ownership")
    status, body = request(
        "PATCH",
        f"/rest/v1/events?id=eq.{eid}",
        token=mallory["token"],
        body={"title": "hijacked"},
        prefer="return=representation",
    )
    check("non-host cannot edit an event", not body, f"got {status} {body}")

    status, body = request("DELETE", f"/rest/v1/events?id=eq.{eid}", token=mallory["token"],
                           prefer="return=representation")
    check("non-host cannot delete an event", not body, f"got {status} {body}")
    print()

    print("Feed view (migration 0006)")
    status, body = request(
        "GET", f"/rest/v1/events_with_counts?id=eq.{eid}&select=id,participant_count",
        token=bob["token"],
    )
    ok = isinstance(body, list) and len(body) == 1 and body[0].get("participant_count") == 0
    check("view exposes participant_count", ok, f"got {status} {body}")

    status, body = request(
        "GET", f"/rest/v1/events_with_counts?id=eq.{eid}&select=id", token=mallory["token"]
    )
    check("view does not leak past RLS", body == [], f"SECURITY_INVOKER MISSING. {status} {body}")
    print()

    failed = [r for r in RESULTS if not r[1]]
    print(f"{len(RESULTS) - len(failed)}/{len(RESULTS)} passed")
    if failed:
        print("\nFAILED:")
        for name, _, detail in failed:
            print(f"  - {name}: {detail}")
    print(
        "\nTest users remain in auth.users. Remove them from the dashboard "
        "(Authentication -> Users, filter 'rlstest+') when you're done."
    )
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
