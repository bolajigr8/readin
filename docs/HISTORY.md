# ReadIn — history, state and lessons (keep this current: `/handoff`)

Last update by the previous assistant (claude.ai chat): November 2026, after releasing app **v9**, server **v7**, admin **v2**.
Code was written and tested in a sandbox that could NOT run Flutter/Dart (only a syntax parser + a static checker);
the server and admin were really built/tested there. **You (Claude Code) can run the real toolchain — start with
`/verify-all` to learn the true baseline; the last results Michael reported: `flutter analyze` clean after v9 fixes,
198+ tests, 1 failing reader-server test that was then fixed (unconfirmed).**

## 1. Timeline of what exists
| Release | What was added |
|---|---|
| v1–v3 | Port of the React-Native app to Flutter: auth, library, Discover (Project Gutenberg via gutendex), reader (EPUB via epub.js in a WebView, PDF via pdfrx), notes/highlights/bookmarks, profile, themes |
| v4 | local-first import (books stored on the phone, synced), document viewer (Word/Excel/text/comics), shelves/badges/reading challenge, notes export, ambient sounds, read-aloud (flutter_tts + Kotlin foreground service), icon generator, About page |
| v5–v6 | Habit tracker (calendar, streaks, native Kotlin reminders, 14-day server-enforced free trial, paywall, cloud sync with 409 merge), admin API (users, features, audit), entitlements engine, admin panel (Next.js BFF), open-last-book, "on this phone" scan, tap-zone fixes, Gutenberg retries/cache |
| v7 | Server hardening (trust proxy, RevenueCat webhook hardened, Google ID-token verification), Google sign-in switched OFF (`kGoogleSignInEnabled=false`) |
| v8 / server v7 | **Paystack** payments in naira (plans set in admin, payments on/off switch, free-for-everyone flag, receipts), professional HTML e-mails + branded pages (verify, reset, payment result, landing, 404), resend-verification, health-check/cron fix, rate limiters fail open, plan expiry read from DB, admin Billing/Guide pages, "Verify email now", revenue stats; reader: bundled offline fonts, bold default, quick settings panel, live font/line-spacing/margins |
| v9 / admin v2 | Eased page-turn animation (Slide/None), opaque toasts, unused-import fixes, 45 s feature refresh, Paystack 403 diagnostics + admin **Test connection**, `tool/fix_android.sh` |

## 2. Root causes already found (do not rediscover)
* **Cron job failing/disabled**: `/api/v1/health` was after the rate limiter (429) and the server only listened after DB connect. Fixed (health first, listen first).
* **E-mail buttons showed raw text**: missing `<a` tag in the old HTML. Reset/verify links pointed to pages/JSON that did not exist → now real pages `/reset-password`, `/verify-email`.
* **All users shared one rate-limit bucket** (no `trust proxy` on Render). Fixed. Auth limiter now counts only failed attempts.
* **Reader fonts did nothing**: the controller coerced every family except `serif` to `sans-serif`; **line-height** lost to the book's own `p{}` rule; **margins** never worked in paged mode because epub.js controls padding through `gap`. All fixed in `reader.html` + controller and verified in Chromium.
* **epub.js `rendition.manager` is created asynchronously** — a hook installed right after `renderTo` silently did nothing; use `rendition.started.then(...)`.
* **Feature/payment switches seemed slow**: the app refreshed access at most once per 8 min and never while open; now every 45 s + on resume (and sign-out/in no longer needed). Server caches are 15–30 s and invalidated on admin write.
* **Paystack "initialize failed: 403 Paystack answered HTTP 403"**: the answer was not JSON (firewall page). Server now sends a User-Agent, logs the body snippet, and admin has *Test connection*. **Unconfirmed in production — first thing to verify (S0).**
* **Gradle "project 'app' not found"** after copying a zip over the project: zips don't ship `android/settings.gradle*`; see `tool/fix_android.sh`.
* **Dart URL normalisation** broke a `fonts/../book.bin` test (the client rewrites `..`).

## 3. Verified-by-test facts (so you know what is trustworthy)
* Server: real `tsc` clean; unit tests billing 10, entitlements 14, revenuecat 8; a full end-to-end script (real MongoDB + Redis, fake Paystack/Resend) passed **92/92** — covers register/confirm/reset e-mails & pages, plans, checkout, exactly-once settlement even with 3 concurrent paths, webhook signature, amount mismatch, expiry, admin endpoints, rate limits, Redis outage fail-open. That script lived only in the sandbox (`/tmp/e2e2`) → **recreating it as a committed integration test is roadmap item S0.4.**
* Admin: real `next build` + a mock-API end-to-end (login, httpOnly cookies, whitelist, CSRF, refresh) + screenshots.
* Reader: Playwright/Chromium harness with a generated test EPUB measured computed styles for every setting, font loading, page-turn animation (15 monotonic scroll steps, same final pages as instant mode, 60 pages across a chapter boundary). **Recreate it under `project/mobile/tool/reader_harness/` (S0.5)** if you change `reader.html`.
* Flutter code was never compiled by the previous assistant. Trust `flutter analyze`/`flutter test` results from your machine over anything written here.

## 4. Production facts
* API: `https://readin-ehzw.onrender.com/api/v1` (Render free, Docker, `autoDeploy`). Render env: `MONGODB_URI, JWT_SECRET, JWT_REFRESH_SECRET, UPSTASH_REDIS_URL, RESEND_API_KEY, EMAIL_FROM, CLOUDINARY_*, PAYSTACK_SECRET_KEY, APP_URL, ADMIN_EMAILS, CLIENT_ORIGIN, REVENUECAT_WEBHOOK_SECRET, CONVERSION_ENABLED=false, TEMP_DIR`. (Never print values.)
* Paystack dashboard: webhook `https://readin-ehzw.onrender.com/api/v1/webhooks/paystack`; callback `https://readin-ehzw.onrender.com/payment/callback`.
* Admin on Vercel: Root Directory `admin`, env `API_URL=https://readin-ehzw.onrender.com/api/v1`.
* Admin accounts: created with `npx tsx src/scripts/create-admin.ts` (env `ADMIN_EMAIL`, `ADMIN_PASSWORD`); the API ALSO requires the e-mail to be in `ADMIN_EMAILS` (second lock). Demo `@readin.test` users must be removed from prod (`remove-test-users.ts --confirm`). **Never run `seed` on prod.**
* Icons: `lib/constants/ionicons.dart` + the font block in `pubspec.yaml` are generated locally from the real Ionicons font by `tool/gen_ionicons.dart` (command in `project/mobile/COMMANDS.md`). Current state (2026-11-05): the committed `ionicons.dart` is a hand-kept Material-icon shim, there is no Ionicons font block in `pubspec.yaml` and `assets/fonts/Ionicons.ttf` is not in the repo.
* Test device: Samsung SM-A175F. Flutter 3.47.6 / Dart 3.13.5 / Gradle 9.3.1 / Android SDK 37 (licences may need `flutter doctor --android-licenses`).

## 5. Michael's open requests (as of this file)
See `ROADMAP.md` — APK release + versioning + landing page, Firebase Analytics/Crashlytics, subscription analytics, biometric sign-in (instead of "remember me"), full admin team/roles, Play readiness (two build flavors), faster feature propagation (done in v9, verify), Paystack 403 (verify).

## 6. Session log
(Append new entries below via `/handoff`.)

### 2026-11-05 — onboarding (first Claude Code session) · stage: pre-S0
* **Layout truth**: app = `project/mobile` (Flutter, pubspec `readin_flutter`, tracked in git); `flutter/readin_flutter` never held the app. Expo leftovers only: `app.json`, `eas.json`, lint-staged/husky `mobile` lines, `server/expo-app-details.txt`, Expo text in `README.md`.
* **Changed**: commit `160094b` = snapshot of all uncommitted v4–v9 work (67 added, 148 deleted = unused ios/linux/macos/web/windows, 98 modified). Docs only otherwise: paths fixed in root/sub CLAUDE.md, `.claude/commands`, ROADMAP, HISTORY, MANUAL_TASKS, PLAY_AND_DISTRIBUTION, DECISIONS (8–11), FIRST_PROMPT, NEXT; app CLAUDE.md moved to `project/mobile/`.
* **No new env vars, packages or tests.**
* **True baseline**: server typecheck ✅, unit tests 32 ✅ (billing 10, entitlements 14, revenuecat 8), lint ❌ (1145 errors, 1137 from `dist/`); admin tsc ✅, lint ✅ (1 warning), build ✅, proxy 7 ✅; flutter analyze ✅, tap-zones 4 ✅, viewer-core 9 ✅, audit_dart ❌ (Windows console encoding; 1 finding `Ionicons._`); flutter test ❌ (no MSVC for `pdfium_dart` hook); release APK ✅ but debug-signed.
* **Secret scan** of every commit: clean (placeholders only). Root `.gitignore` covers only `.env` (gap → S0.3).
* **Gotchas**: ESLint `ignores` inside a rules object is not global; `audit_dart.py` needs `PYTHONIOENCODING=utf-8`; first release build takes ~22 min; `flutter_tts` applies KGP (future Flutter will refuse); husky hook dormant until root `pnpm install`, then it would block every commit.
* **Left undone**: all of S0 (awaiting go), `flutter test` run, real-device tests.

### 2026-11-05 — stage S0 (baseline, hygiene, tests)
* **Changed**: `mobile/ios/` restored (template); server `eslint.config.mjs` (global ignores, test globals), `calibre.service.ts` (error cause); `mobile/tool/audit_dart.py` (Windows UTF-8 + path fix — `Ionicons._` was a false positive); root/admin `.gitignore`; Expo files removed (tag `expo-legacy`); husky hook rewritten; root lint-staged removed, server lint-staged = `pnpm --dir server exec eslint --fix`; README; Dockerfile pnpm pin; render.yaml + `.env.example` names; `mobile/lib/app/access_refresh.dart` (+ `app.dart` uses it, same behaviour); `tool/verify.sh`.
* **Tests added**: server e2e `tests/e2e/run.mjs` **22** (`pnpm run test:e2e`); reader harness `mobile/tool/reader_harness/harness.mjs` **17** (installed Edge/Chrome); app `test/features/access_refresh_test.dart` **8** (written, not run yet).
* **New dev packages**: `mongodb-memory-server` ^11.3.0 (server), `playwright-core` 1.56.1 (reader harness only). No new env vars (test-only `RESEND_BASE_URL` is read by the Resend SDK itself).
* **True counts now**: server unit 32 + e2e 22; admin proxy 7; app JS 4 + 9; reader 17; flutter test still blocked (VS C++).
* **Gotchas**: server sends e-mails after responding (tests must wait); `dotenv/config` would load the real `server/.env` into a test server — use `DOTENV_CONFIG_PATH`; MongoDB download is ~650 MB on Windows; lint-staged runs from the repo root and can't find `server/node_modules/.bin` on Windows; `.prettierrc` disagrees with the code style (prettier kept out of the hook); lint-staged backup/restore rewrites line endings (harmless).
* **Left**: S0.2 (Michael), run S0.6 test after VS C++, rebuild APK once (`verify.sh --apk`), commit + push (+ tag).

### 2026-11-06 — S0 merged, Paystack confirmed
* PR #1 (S0) merged by Michael; Render redeployed. Admin Billing → Test connection: **"Connected. Paystack accepted the key."** — the 403/firewall problem from §2 is resolved in production (S0.2 done). Full checkout not yet exercised live (S10).
* Git workflow: branches `feat/ fix/ chore/ docs/ refactor/ test/` → PR → Michael merges (DECISIONS #13); direct pushes to `main` are rejected by GitHub (`commit_refs_rules`).

### 2026-11-06 — S0 complete
- Michael installed VS Build Tools 2026 "Desktop development with C++"; `flutter doctor` clean.
- `flutter test`: 202/202 pass (first full run on this PC), incl. 8 new access-refresh tests (S0.6). S0.1–S0.7 all ticked.
- Full counts: server unit 32, e2e 22, admin proxy 7, app 202, tap 4, viewer 9, reader harness 17.
- Next: S1 release signing.

### 2026-11-06 — S1 signing & release pipeline (branch `feat/s1-release-signing`)
- Release builds now FAIL without `android/key.properties` + keystore (no silent debug key). Test-only opt-out
  `-P ALLOW_DEBUG_SIGNING=true` / `READIN_ALLOW_DEBUG_SIGNING=true`; `verify.sh --apk` uses it only when no key exists.
- New: `mobile/android/key.properties.example`, `mobile/tool/build_release.sh` (checks → universal + per-ABI → apksigner
  certificate check, refuses debug/mixed certs → `build/release/<ver>/` + notes with SHA-256/SHA-1/sizes/checksums),
  `mobile/tool/bump_version.dart` (versionCode +1 always), `res/xml/data_extraction_rules.xml`.
- Backup OFF (`allowBackup=false` + extraction rules) — DECISIONS #14. 3 release `debugPrint`s made debug-only.
- No new packages / env vars / server changes. Tests: app 202, tap 4, viewer 9; signing paths tested with a throwaway key.
- Gotchas: Dart `\s*$` in multiLine regex eats line endings; apksigner 37 prints "V2 Signer: certificate … digest:".
- Left: S1.1 keystore + S1.6 real phones (Michael).

### 2026-11-06 — S8 flavors (branch `feat/s8-play-flavor`) + payment decisions
- Decisions #16/#17: Play version = Google Play Billing (monthly + yearly, RevenueCat) — next; APK = Paystack (paused: Paystack's
  Cloudflare blocks POST /transaction/initialize from Render, Ray ID a564e9a499c6e5c0-PDX; support contacted).
- Flavors `direct` (APK, Paystack, MANAGE_EXTERNAL_STORAGE) / `play` (AAB, none of these), same applicationId, `default-flavor: direct`.
  `lib/core/distribution.dart`; `billingVisibleProvider` gates every buying UI; `X-App-Distribution` header; server refuses Paystack from play.
- `tool/build_play.sh` (AAB + signature + manifest checks); `build_release.sh` uses `--flavor direct`.
- Tests: app 213, server e2e 26. Both builds produced with the real key. Gotcha: grep a manifest for the permission ENTRY, not the word.
