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
* Reader: Playwright/Chromium harness with a generated test EPUB measured computed styles for every setting, font loading, page-turn animation (15 monotonic scroll steps, same final pages as instant mode, 60 pages across a chapter boundary). **Recreate it under `flutter/readin_flutter/tool/reader_harness/` (S0.5)** if you change `reader.html`.
* Flutter code was never compiled by the previous assistant. Trust `flutter analyze`/`flutter test` results from your machine over anything written here.

## 4. Production facts
* API: `https://readin-ehzw.onrender.com/api/v1` (Render free, Docker, `autoDeploy`). Render env: `MONGODB_URI, JWT_SECRET, JWT_REFRESH_SECRET, UPSTASH_REDIS_URL, RESEND_API_KEY, EMAIL_FROM, CLOUDINARY_*, PAYSTACK_SECRET_KEY, APP_URL, ADMIN_EMAILS, CLIENT_ORIGIN, REVENUECAT_WEBHOOK_SECRET, CONVERSION_ENABLED=false, TEMP_DIR`. (Never print values.)
* Paystack dashboard: webhook `https://readin-ehzw.onrender.com/api/v1/webhooks/paystack`; callback `https://readin-ehzw.onrender.com/payment/callback`.
* Admin on Vercel: Root Directory `admin`, env `API_URL=https://readin-ehzw.onrender.com/api/v1`.
* Admin accounts: created with `npx tsx src/scripts/create-admin.ts` (env `ADMIN_EMAIL`, `ADMIN_PASSWORD`); the API ALSO requires the e-mail to be in `ADMIN_EMAILS` (second lock). Demo `@readin.test` users must be removed from prod (`remove-test-users.ts --confirm`). **Never run `seed` on prod.**
* Icons: `lib/constants/ionicons.dart` + the font block in `pubspec.yaml` are generated locally from the real Ionicons font by `tool/gen_ionicons.dart` (command in `flutter/readin_flutter/COMMANDS.md`); the zip ships a Material-icon shim.
* Test device: Samsung SM-A175F. Flutter 3.47.6 / Dart 3.13.5 / Gradle 9.3.1 / Android SDK 37 (licences may need `flutter doctor --android-licenses`).

## 5. Michael's open requests (as of this file)
See `ROADMAP.md` — APK release + versioning + landing page, Firebase Analytics/Crashlytics, subscription analytics, biometric sign-in (instead of "remember me"), full admin team/roles, Play readiness (two build flavors), faster feature propagation (done in v9, verify), Paystack 403 (verify).

## 6. Session log
(Append new entries below via `/handoff`.)
