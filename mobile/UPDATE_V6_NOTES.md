# Update v6 — habit tracker as a 14-day free trial, server-saved data, admin control

**ORDER MATTERS: deploy the server first (see `readin_server_v6.zip` → `server/ADMIN_SETUP.md`), then update the app.**

## What users see
* First time they open **Habits**: "Try it FREE for 14 days" page → **Start my 14-day free trial** (the server starts the clock once; it cannot be restarted by the user).
* During the trial: a yellow strip on top of the tracker ("12 days left…", red in the last 3 days, "Last day!" on day 14) and a "N days free" chip on the Home card.
* After 14 days: **"Your free trial has ended"** page with *See ReadIn Premium*. Reminders stop, page counting stops, the Home card shows it is locked. Their habits are kept and come back if they upgrade or you grant access.
* Premium users and the admin: full access, no banner. (Premium itself is still "coming soon", so for now you can give anyone Premium or a gift period from the admin API.)
* The app **never locks anybody out because the server is asleep or offline**: it uses the last known answer; a cached trial still expires on its own date.

## Your data is now safe
* **Habits** and **shelves / statuses / favourites** are saved on the server per user (versioned, merged on conflicts, never overwritten) → reinstalling or changing phone no longer loses them. Existing local data is uploaded automatically the first time.
* Signing out / switching account wipes the local copy, so two people sharing a phone never see (or upload) each other's data.

## Apply (app)
1. Deploy the server first.
2. Close the app, unzip `readin_flutter_update_v6.zip` over your project (keeps your icon font).
3. `flutter pub get` → `flutter analyze` → `flutter test` → `flutter run --release`.
   (No new packages.)

## Test list
1. Sign in with a normal (non-admin) account → Sidebar → Habits → trial intro → start → create a habit.
2. Reinstall / sign in on another phone → the habit is there.
3. Admin API (later the Next.js panel) → set `trialDays` to 0 / grant 30 days / reset trial → reopen Habits and see the state change.
4. Sign in as the admin account → Habits works with no banner.

## Honest limits
* Not compiled by me — the new Dart sync code and the server TypeScript are the likeliest first errors; send them over.
* "Premium" can't be bought yet; until it exists, give access from the admin API.
* Merging two phones never deletes: a habit deleted on phone A can come back if phone B still had it.
