# Shotgun

> **Call shotgun on what your friends are already doing.**
> A host posts something they're about to do with spare capacity (a grocery run, an
> errand) and the friends they choose can join in — free, or chip in over Venmo.

This repo is the MVP scaffold: a native iOS app (Swift 6 / SwiftUI) on top of
Supabase (Postgres + Row-Level Security + Auth + Storage). The whole thing exists
to prove one loop end to end:

> host creates an event → allowed friends see it → a friend joins → (if paid) they
> settle over Venmo → the event closes.

> **Name:** "Shotgun" is a working title taken from the one-liner. To rename,
> change `name:` in `project.yml`, the bundle id, and the folder, then regenerate.

---

## Prerequisites

- **macOS + Xcode 16+** (iOS 17 SDK, Swift 6). Install from the App Store.
- **Homebrew** — https://brew.sh
- An **Apple Developer Program** membership ($99/yr) when you're ready for TestFlight.
- A **Supabase** project — https://supabase.com (free tier is fine to start).

The bootstrap script installs the rest (`xcodegen`, `swiftlint`, `supabase` CLI).

---

## Quick start

```bash
# 1. Install tooling, create your local secrets file, and generate the project.
make bootstrap

# 2. Fill in your Supabase credentials.
#    Edit Config/Secrets.xcconfig  (Supabase Dashboard → Project Settings → API)

# 3. Re-generate so the new config is baked into Info.plist, then open Xcode.
make open
```

In Xcode: select the **Shotgun** scheme, pick a simulator or your device, and Run.
For a device build, set your team under **Signing & Capabilities**.

> The Xcode project is **generated** from `project.yml` and is git-ignored. Never
> edit `Shotgun.xcodeproj` by hand — change `project.yml` and run `make generate`.

---

## Backend setup (Supabase)

The schema, security policies, and the capacity-safe join RPC live in
`supabase/migrations/`. Apply them to your project:

```bash
supabase login
supabase link --project-ref YOUR-PROJECT-REF
make db-push        # applies all migrations to the remote database
```

Or develop fully locally against Docker:

```bash
make db-start       # boots Postgres + Auth + Studio locally
make db-reset       # replays every migration into the local db
```

Then, in the Supabase dashboard:

1. **Auth → Providers → Phone**: enable it and connect **Twilio** (SMS OTP).
   Remember A2P 10DLC registration before sending invite texts in production.
2. **Auth → Providers → Apple**: enable Sign in with Apple (Service ID + key).
3. **Database → Extensions**: enable `pg_cron`, then uncomment the
   `cron.schedule(...)` line in `0004_rpc_and_jobs.sql` to auto-expire events.
4. **APNs**: add a token-based key for push (the two MVP notifications).

---

## Project structure

```
Shotgun/
├── App/                # @main entry, AppState (session + routing), RootView
├── Core/
│   ├── Config/         # AppConfig — reads Supabase creds from Info.plist
│   ├── Supabase/       # shared SupabaseClient
│   ├── Models/         # Codable structs mirroring the DB tables + enums
│   ├── Services/       # Auth / Profile / Friends / Events (the API layer)
│   └── Utilities/      # formatters, Venmo deep-link builder
└── Features/           # one folder per screen: View + @Observable ViewModel
    ├── Auth/           # phone OTP + Sign in with Apple
    ├── ProfileSetup/   # name + Venmo handle
    ├── Feed/           # time-sorted feed of joinable events
    ├── CreateEvent/    # host form
    ├── EventDetail/    # join/leave, participants, Venmo handoff, host controls
    ├── Friends/        # requests, friends, close-friend toggle, search
    ├── Activity/       # hosted + joined history
    ├── Account/        # profile + sign out
    ├── Main/           # the tab bar
    └── Shared/         # MoneyPill, AsyncButton, Apple nonce helpers

supabase/migrations/    # 0001 schema · 0002 security fns · 0003 RLS · 0004 RPC+jobs
Config/                 # Secrets.xcconfig (git-ignored) + .example template
project.yml             # XcodeGen spec — source of truth for the Xcode project
```

Architecture: **MVVM with `@Observable`**. Views are thin; each owns a `@MainActor`
view model that calls a stateless `Service`. Services wrap `supabase-swift`. The
privacy model is enforced in the database via RLS, not in the app.

## Data model

| Table | Purpose |
|-------|---------|
| `profiles` | 1:1 with `auth.users`; display name, photo, Venmo handle |
| `friendships` | mutual friend graph (one row per pair, `pending`/`accepted`) |
| `close_friends` | directional "close friend" label the owner applies |
| `events` | the happenings: what/where/when, capacity, audience, money |
| `event_participants` | who joined, their note, and a `paid` flag |

Key guarantees enforced in SQL:

- **Audience RLS** — you can only `SELECT` an event if you're the host, an accepted
  friend (audience `friends`), or a marked close friend (audience `close_friends`).
- **Capacity race-safety** — joins go through the `join_event()` RPC, which locks the
  event row, checks capacity, and auto-closes when the last seat fills.
- **Expiry** — `expire_events()` closes events past their window (run via `pg_cron`).

---

## Common tasks

```bash
make help        # list all targets
make generate    # regenerate the Xcode project from project.yml
make open        # generate + open in Xcode
make lint        # SwiftLint
make test        # run unit tests on a simulator
make db-push     # apply migrations to the linked remote
make db-reset    # reset + replay migrations locally
```

## What's stubbed (intentional next steps)

These are wired structurally but left as TODOs for you to flesh out:

- **Profile photo upload** to the `avatars` storage bucket (bucket + RLS exist).
- **Push notifications** (APNs key, device-token registration, edge-function fan-out
  for the two MVP pushes: "X is going…" and "Y joined your run").
- **Realtime** live participant updates (currently pull-to-refresh).
- **Contacts-based friend finding** (Contacts entitlement + usage string are set up).
- An **edit-profile** screen (reuse `ProfileSetupView` in edit mode).

> **Note:** the Swift sources were written against the `supabase-swift` v2 API but
> haven't been compiled in this environment (no Xcode). Build in Xcode and resolve
> any SDK signature drift — most likely candidates are the auth calls in
> `AuthService` and the PostgREST query builders in the services.
