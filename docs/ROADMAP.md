# ROADMAP — staged plan (work one stage at a time with `/stage Sx`)

Legend: **[C]** Claude Code does it · **[M]** only Michael can (see MANUAL_TASKS.md) · ⚠ needs approval before coding.
Every stage ends with: verification (CLAUDE.md §6) → manual test steps for Michael → `/handoff`.
Order matters: S0 → S1 → S2 → S3 are needed to start acquiring users safely; S4–S6 can follow in any order; S7–S8 make Play smooth.

---
## S0 — Baseline, hot fixes, hygiene  (do first)
- [x] S0.1 [C] (done 2026-11-06: VS Build Tools 2026 C++ installed → `flutter test` 202/202 pass; everything else green 2026-11-05) Run `/verify-all`; fix every failure/warning in the app, server, admin. Record true test counts in HISTORY. Baseline 2026-11-05 (see `sessions/2026-11-05-onboarding.md`): server lint fails (`ignores` in `eslint.config.mjs` is not global → `dist/` linted; `calibre.service.ts:29,53` preserve-caught-error; tests need Node globals); `audit_dart.py` crashes on the Windows console (set UTF-8 output) and reports `Ionicons._` (check false positive); admin lint 1 warning (`src/lib/api.ts:46`); `flutter test` blocked until Michael installs the VS C++ workload.
- [x] S0.2 [M+C] (done 2026-11-06: after deploying S0, admin Billing → Test connection = "Connected. Paystack accepted the key.") **Paystack 403**: Michael deploys server v7, opens admin → Billing → *Test connection*. If it still reports the firewall block, investigate (alternatives: different HTTP client/headers, retry with backoff, region, contact Paystack support) — do not guess; use the new log line (`[payments] initialize failed … | body:`).
- [x] S0.3 [C] (done 2026-11-05) **Git hygiene**: ~~put the app under version control~~ — the app is `project/mobile` and is tracked; all uncommitted v4–v9 work was committed as a snapshot (`160094b`, 2026-11-05). Remaining: root `.gitignore` → `.env*` + `!.env.example`, `build/`, `.dart_tool/`, `admin/.next`, `site/.next`, `key.properties`, `*.jks`, `*.keystore`. Secret scan of all history done 2026-11-05: clean (only placeholders in `.env.example`) — re-run after changes. **Expo leftovers**: tag `expo-legacy`, then delete `project/app.json`, `project/eas.json`, `server/expo-app-details.txt`, the lint-staged `mobile/**/*.{ts,tsx,js,jsx}` entry; rewrite `project/README.md` for the Flutter app. **Husky**: rewrite `.husky/pre-commit` (server lint-staged + typecheck; admin `tsc` when admin files are staged; `flutter analyze` when mobile files are staged). Pin Dockerfile `pnpm@10.28.1`; add missing env names to `render.yaml` (`PAYSTACK_SECRET_KEY`, `ADMIN_EMAILS`, `CONVERSION_ENABLED`, `GOOGLE_CLIENT_ID(S)`) and dedupe `APP_URL` in `.env.example`.
- [x] S0.4 [C] (done 2026-11-05: `server/tests/e2e/run.mjs`, 22 tests, `pnpm run test:e2e`) **Server integration tests** committed in `server/tests/e2e/`: real MongoDB (use `mongodb-memory-server`, or Docker if available) + Redis (or `ioredis-mock`) + a fake Paystack/Resend server. Port the scenarios listed in HISTORY §3 (register→confirm→login, reset, plans, checkout, exactly-once settlement incl. concurrent verify+webhook+callback, bad webhook signature, amount mismatch, expiry, admin endpoints, rate-limit fail-open). Add `pnpm run test:e2e`.
- [x] S0.5 [C] (done 2026-11-05: `mobile/tool/reader_harness`, 17 tests, uses installed Edge/Chrome) **Reader harness** committed in `project/mobile/tool/reader_harness/` (Playwright + generated EPUB) with the checks from HISTORY §3; run it whenever `assets/reader/reader.html` changes.
- [x] S0.6 [C] (done 2026-11-06: `lib/app/access_refresh.dart` + `test/features/access_refresh_test.dart`, 8/8 pass) Verify **feature/payment propagation**: toggling a feature or payments in admin reaches a running app within ~60 s (timer + resume refresh in `lib/app/app.dart`); add a widget/provider test. Consider a `configVersion` field in `/features/me` + `/config/public` so the app can skip re-parsing unchanged data.
- [x] S0.7 [C] (done 2026-11-05: `project/tool/verify.sh`) Make `tool/verify.sh` (runs CLAUDE.md §6) so Michael can run it without Claude Code.

## S1 — Signing & release pipeline ⚠ (see PLAY_AND_DISTRIBUTION.md §2)
- [x] S1.1 [M] (done 2026-11-06: key created by Michael, fingerprints in PLAY_AND_DISTRIBUTION §2.2; backups = Michael) Generate the release keystore (exact command in the doc), 2 offline backups, record the certificate SHA-256 + SHA-1 in the doc (fingerprints only — never the passwords).
- [x] S1.2 [C] (done 2026-11-06: release build fails without the key — tested; `key.properties.example`; opt-out `-P ALLOW_DEBUG_SIGNING=true` tested) `android/key.properties` (git-ignored) + `key.properties.example`; `app/build.gradle.kts`: **release must fail if the key is missing** (remove the silent debug-key fallback) — keep an explicit `--dart-define`/Gradle property `ALLOW_DEBUG_SIGNING=true` for local `flutter run --release` only.
- [x] S1.3 [C] (done 2026-11-06: `mobile/tool/bump_version.dart`, doc §3) Version scheme: `pubspec.yaml version: x.y.z+N`; N strictly increasing (also used as `versionCode`); document in the doc; `tool/bump_version.dart` helper.
- [x] S1.4 [C] (done 2026-11-06: `mobile/tool/build_release.sh` tested end-to-end with a throwaway key; gallery debug-only confirmed; logging debug-only; no `proguard-rules.pro` added — Flutter's default R8 rules; the real-phone release test is part of S1.6) Production config: `API_BASE_URL` default is already prod; add `tool/build_release.sh` that runs verification, builds universal + per-ABI APKs, runs `apksigner verify --print-certs`, prints SHA-256/size. Release must not include: the `/dev/gallery` route (debug-only already — confirm), logging of tokens/bodies, debug banners. Review R8/shrink rules (`proguard-rules.pro`) so the WebView/TTS/Kotlin pieces survive minification — test a release APK on a real phone.
- [x] S1.5 [C] (done 2026-11-06: backup OFF — `allowBackup="false"` + `data_extraction_rules.xml`; network config unchanged, DECISIONS #14) Review `AndroidManifest.xml` + `network_security_config.xml` (cleartext only for 127.0.0.1/localhost — keep). Add `android:allowBackup` decision (recommend `false` or restricted backup rules because tokens live in secure storage).
- [ ] S1.6 [M] Install the signed APK on ≥3 real phones (different Android versions, incl. Samsung A175F); install **over** the previous build to prove updates work without uninstalling.

## S2 — Version management & in-app update prompt
- [ ] S2.1 [C] Server: `AppRelease` model + `GET /api/v1/app/version?versionCode=&platform=android` (public, cacheable 60 s) returning `{latestVersion, latestVersionCode, minSupportedVersionCode, updateAvailable, mandatory, downloadUrl, sha256, sizeBytes, releaseNotes, releasedAt}`; admin endpoints (permission `releases.write`) to create/publish/unpublish releases. Validation: https URL only, hostname allow-list from env `RELEASE_HOST_ALLOWLIST`. Unit + integration tests.
- [ ] S2.2 [C] Admin page **Releases** (list, create, mark latest, set minimum supported, mandatory toggle with plain-language explanation, release notes, checksum). Add to proxy whitelist + tests.
- [ ] S2.3 [C] App `UpdateService` (check at launch + on resume, throttled ≥6 h; sends `X-App-Version`/`X-App-Build` headers on all API calls too). Optional update → non-blocking banner/dialog "Update later / Update"; **mandatory** → full-screen blocking page with the download button. **Never interrupt an open reading session**: show prompts only on Home/Library (queue while the reader is open). Open the URL with `url_launcher` (external browser). No silent install, no `REQUEST_INSTALL_PACKAGES`. Show the checksum on the landing page, not in-app.
- [ ] S2.4 [C] Tests: version comparison edge cases, throttling, mandatory gate, offline/server-asleep behaviour (never block a user because the version server is unreachable).
- [ ] S2.5 [M] Publish release 1.0.0 in admin once S1+S3 are live.

## S3 — Landing page (Vercel) — see LANDING_PAGE_PLAN.md
- [x] S3.1 [C] (done 2026-11-06 as plain HTML for Cloudflare Pages — download buttons driven by `site/release.json` until S2's /app/version exists; `tool/site_check.mjs` 150 checks + `tool/site_browser.mjs` 11 tests) New `project/site/` (Next.js static/ISR, same toolchain as admin): download button, version/size/date/checksum from `GET /app/version`, release notes, install guide with Play-Protect / unknown-sources / Samsung Auto-Blocker steps, FAQ, QR code, links to `/privacy`, `/terms`, `/delete-account`.
- [x] S3.2 [C] (done 2026-11-06: /privacy, /terms, /delete-account — DRAFTS for Michael's review) Pages `/privacy`, `/terms`, `/delete-account` (drafts; flagged "to be reviewed by Michael/lawyer").
- [x] S3.3 [C] (done 2026-11-06: render.yaml buildFilter server/**; site needs no build) `render.yaml` buildFilters so API redeploys only for `server/**`; Vercel ignored-build-step docs for `admin` and `site`.
- [ ] S3.4 [M] Create the Vercel project (Root Directory `site`), host the APK (GitHub Releases `readin-releases`), (optional) buy a domain.

## S4 — Biometric sign-in — see BIOMETRIC_PLAN.md ⚠ (touches MainActivity + auth flow)
- [ ] S4.1 [C] `local_auth`; `MainActivity` → `FlutterFragmentActivity` (required by the plugin); manifest `USE_BIOMETRIC`; `BiometricService` interface + fake for tests.
- [ ] S4.2 [C] Profile switch "Unlock with fingerprint / face" (ON requires a successful scan first); lock screen on cold start and after N minutes in background; 3 failures or "Use password instead" → sign out → sign-in screen. Server unaffected; password never stored.
- [ ] S4.3 [C] Tests (provider logic with fake service, lifecycle timing) + manual device test list.

## S5 — Admin team & roles — see ADMIN_ROLES_PLAN.md ⚠ (DB schema + auth)
- [ ] S5.1 [C] Server: roles `user | tester | admin | owner`, `permissions[]`, migration (existing `role:'admin'` + `ADMIN_EMAILS` → `owner`), `requirePermission()`, last-owner protection, audit entries, session revocation on role change. `ADMIN_EMAILS` stays as *break-glass owner bootstrap* only.
- [ ] S5.2 [C] Endpoints: `GET/POST/PATCH/DELETE /admin/team…`, `PATCH /admin/users/:id/role`; re-authentication (password) for team changes.
- [ ] S5.3 [C] Admin UI: **Team** page (list, add by e-mail, role + permission checkboxes with plain explanations, remove), role selector on the user page, sidebar items hidden by permission (server enforces), Guide page updated.
- [ ] S5.4 [C] Entitlements: `tester` = all features + Premium-equivalent without admin access; document in Features help text.
- [ ] S5.5 [C] Tests: permission matrix (every route × every role), cannot demote self/last owner, e2e.
- [ ] S5.6 [later] TOTP 2FA for admin/owner.

## S6 — Firebase Analytics + Crashlytics — see ANALYTICS_PLAN.md ⚠ (privacy)
- [ ] S6.1 [M] Create the Firebase project, register `com.micbol.readin` with release **and** debug SHA-1/SHA-256, download `google-services.json` (placed in `android/app/`, git-ignored), enable DebugView/Crashlytics.
- [ ] S6.2 [C] Packages `firebase_core`, `firebase_analytics`, `firebase_crashlytics`; Gradle plugins; manifest meta-data (collection disabled until consent, ad-id collection off, `AD_ID` permission removed); init in `main.dart` with graceful failure when Firebase isn't configured (app must still run).
- [ ] S6.3 [C] `AnalyticsService` (one abstraction, `NoopAnalyticsService` for tests/debug) + event catalogue exactly as in the plan; wire at the real call sites (auth, reader sessions, bookmarks, search, Discover download, habits, paywall/purchase, update prompts). No PII; Firebase-recommended names where they exist.
- [ ] S6.4 [C] Consent: first-launch card (Accept / Decline) + Profile switches (Analytics, Crash reports).
- [ ] S6.5 [C] Crashlytics: Flutter + platform + async error hooks; custom keys `app_version`, `distribution`, `flavor`; sanitise breadcrumbs; hidden test-crash action in the dev gallery (debug only).
- [ ] S6.6 [M] Verify in DebugView and a release build; build the GA4 funnels/explorations listed in the plan.
- [ ] S6.7 [C optional] Server-side `purchase` via GA4 Measurement Protocol for webhook-confirmed payments (env `GA4_MEASUREMENT_ID`, `GA4_API_SECRET`).

## S7 — Compliance & store readiness — see PLAY_AND_DISTRIBUTION.md
- [x] S7.1 [C] (done 2026-11-06: app Profile → Delete account (wipes the phone too) + web /delete-account (e-mail link, 1 h) + DELETE /users/me; payments kept without e-mail; e2e 3 tests) **Account deletion**: server `DELETE /users/me` (password re-check; remove user, library/files in Cloudinary, annotations, bookmarks, progress, synced docs, features; keep anonymised payment records for accounting), in-app Profile → Delete account (typed confirmation), web `/delete-account` page + e-mail-confirmed request flow. Tests.
- [x] S7.2 [C] (done 2026-11-06: Play merged manifest = 8 normal permissions, no restricted ones; MANAGE_EXTERNAL_STORAGE direct-only (S8); foreground-service text + video steps in docs/store/PLAY_CONSOLE_ANSWERS.md §6) Permission audit & flavor manifests (`direct` vs `play`), exact-alarm and foreground-service declarations text, remove unused permissions.
- [ ] S7.3 [C] `/play-audit` → `PLAY_READINESS.md`; fix items.
- [x] S7.4 [C] (done 2026-11-06: docs/store/PLAY_CONSOLE_ANSWERS.md — listing, Data safety, content rating, target audience, app access, release notes; feature graphic + 512 icon; screenshot list for Michael) Store listing text, short/long description, release notes, Data-safety answers, content-rating answers in `project/docs/store/`; screenshot plan (Michael captures).
- [ ] S7.5 [M] Play Console tasks (identity verification, app creation, declarations, closed test, merchant profile).

## S8 — Build flavors (`direct` / `play`) & AAB ⚠
- [x] S8.1 [C] (done 2026-11-06: flavors direct/play, `lib/core/distribution.dart`, `billingVisibleProvider` gates every buying UI, server refuses Paystack from play — see session 2026-11-06-s8-flavors) Gradle product flavors + `--dart-define=DISTRIBUTION=direct|play` exposed as `kDistribution`; `BillingPolicy` abstraction: `direct`→Paystack UI; `play`→consumption-only (no prices/CTAs/links; premium status display only).
- [x] S8.2 [C] (done 2026-11-06: `tool/build_play.sh` → signed AAB + manifest check; upload key optional) `flutter build appbundle --flavor play --release`; signing for upload key; document Play App Signing enrolment with the existing key (PEPK).
- [ ] S8.3 [later] Play Billing mode via RevenueCat (`purchases_flutter`) behind a server flag; server maps RevenueCat events → `premiumUntil` (code exists in `server/src/services/revenuecat.logic.ts`).

## S9 — Subscription hardening
- [ ] S9.1 [C] Paystack events: `charge.success` (done), `refund.processed`, `charge.dispute.create/resolve` → mark payment refunded/disputed, shorten/revoke `premiumUntil` per policy (ask), admin visibility + reconcile button ("re-check with Paystack").
- [ ] S9.2 [C] Expiry UX: in-app banner 5 days before `premiumUntil`, e-mail reminder (job), "Renew" CTA that stacks time; failed/abandoned payments surface; restore = sign in (documented).
- [ ] S9.3 [later] Paystack recurring charges (authorization reuse) — only after S0–S8.

## S10 — QA & release 1.0.0
- [ ] S10.1 [C] `project/docs/QA_REPORT.md` template filled with automated results; manual checklist (below).
- [ ] S10.2 [M] Real-device matrix; Firebase/Crashlytics check; payment test (Paystack test → live switch); update-over-install; landing-page download from a clean phone.

### Manual QA checklist (Michael, real devices)
install · update over previous version (data kept) · register · confirm e-mail · login · forgot/reset password · biometric on/off · books load · Discover download · read EPUB & PDF · progress saved · bookmark/highlight/note · habits (trial → paywall) · pay (test mode) → Premium · payments OFF in admin → app hides payments · expiry · update prompt optional/mandatory · analytics events in DebugView · test crash in Crashlytics · permissions prompts sensible · release signature identical to previous release.
