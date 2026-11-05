# Full sweep — backend + app (v6)

## How it was checked (no Flutter/Dart SDK and no internet in my sandbox)
| Check | Result |
|---|---|
| **Backend TypeScript**, strict mode (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`) over the whole server with typed stand-ins for Express/Mongoose | 0 errors in any file I wrote or changed (remaining messages are limits of the stand-ins in older untouched files) |
| **Trial/access rules** — 12 unit tests (`node --experimental-strip-types tests/entitlements.test.mjs`) | pass |
| **Flutter static audit** (`tool/audit_dart.py`, new): every import resolves · every package is in pubspec · no symbol used without its import · `show`/`hide` lists · every constructor call has valid + all required named arguments · assets exist · every icon exists · enum members valid · members never declared anywhere | 0 problems over 179 files. I proved the tool works by injecting 3 known bugs (the earlier `readBookNow` import bug, a missing import, a misspelled argument): it caught all 3 |
| New Flutter/Dart APIs compared against the version you already compiled (v4) | only valid SDK names added (`showTimePicker`, `TimeOfDay`, `DateFormat.yMMMM`, `Icons.calendar_month`, …) |
| Signatures of every helper my new code calls (toast, sheets, confirm dialog, share, ApiResult…) | all match |
| Kotlin: imports, helpers used by the scanner, bracket balance (3 files) · AndroidManifest well-formed · reader/viewer JavaScript parses · viewer tests (9) | pass |
| Dart tests (`flutter test`) and `flutter analyze` | **not runnable here — run them on your PC** |

## Bugs found and fixed in this sweep
1. **Server never trusted Render's proxy** (already live): all users shared ONE IP for rate-limiting (10 logins / 15 min in total) and the audit log recorded the proxy's IP → `trust proxy` added; default limits raised.
2. **Habit sync could resurrect something deleted while offline** → unsynced local edits are now uploaded first (new test).
3. **Habit-sync pushes** were too frequent (each page turn) for the rate limit → 20 s debounce.
4. **Book picker** in the habit editor cleared the chosen book when you tapped outside → fixed.
5. **Signing out / session expiry could discard edits not yet uploaded** → data is wiped only when a *different* account signs in.
6. **Google sign-in** could be linked to an administrator account → administrators are never linked/accepted.
7. Mongo upserts duplicated filter fields in `$setOnInsert` → removed.
8. Habit alarm receiver was exported to other apps → now private (the system can still deliver boot events).
9. Earlier in this session (already shipped): wrong import hiding `readBookNow`, test type errors, outdated reader-prefs test, real storage used in a test.

## Still unverifiable by me (needs your machine)
* Compilation of the Dart code and the Kotlin code (`flutter analyze`, `flutter run`).
* The server against a real MongoDB/Redis (typecheck + logic tests only). First real calls to try: `GET /api/v1/features/me`, an admin login, `PUT /api/v1/sync/habits`.
* Real-device behaviour: reminders after a reboot, notification permission, scanning the phone.
