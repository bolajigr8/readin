# ROADMAP — staged plan (work one stage at a time with `/stage Sx`)

Legend: **[C]** Claude Code does it · **[M]** only Michael can (see MANUAL_TASKS.md) · ⚠ needs approval before coding.
Every stage ends with: verification (CLAUDE.md §6) → manual test steps for Michael → `/handoff`.
Order matters: S0 → S1 → S2 → S3 are needed to start acquiring users safely; S4–S6 can follow in any order; S7–S8 make Play smooth.

---
## S0 — Baseline, hot fixes, hygiene  (do first)
- [ ] S0.1 [C] Run `/verify-all`; fix every failure/warning in the app, server, admin. Record true test counts in HISTORY.
- [ ] S0.2 [M+C] **Paystack 403**: Michael deploys server v7, opens admin → Billing → *Test connection*. If it still reports the firewall block, investigate (alternatives: different HTTP client/headers, retry with backoff, region, contact Paystack support) — do not guess; use the new log line (`[payments] initialize failed … | body:`).
- [ ] S0.3 [C] **Git hygiene**: put `flutter/readin_flutter` under version control (propose: `git init` there, OR move it into the repo as `project/app` — ask Michael). Add/verify `.gitignore` entries: `key.properties`, `*.jks`, `*.keystore`, `android/local.properties`, `.env*` (except `.env.example`), `build/`, `.dart_tool/`, `admin/.next`, `site/.next`. Verify no secret is tracked (`git ls-files`, and scan history for `.env`, `*.jks`). Archive `project/mobile` per DECISIONS (ask).
- [ ] S0.4 [C] **Server integration tests** committed in `server/tests/e2e/`: real MongoDB (use `mongodb-memory-server`, or Docker if available) + Redis (or `ioredis-mock`) + a fake Paystack/Resend server. Port the scenarios listed in HISTORY §3 (register→confirm→login, reset, plans, checkout, exactly-once settlement incl. concurrent verify+webhook+callback, bad webhook signature, amount mismatch, expiry, admin endpoints, rate-limit fail-open). Add `pnpm run test:e2e`.
- [ ] S0.5 [C] **Reader harness** committed in `flutter/readin_flutter/tool/reader_harness/` (Playwright + generated EPUB) with the checks from HISTORY §3; run it whenever `assets/reader/reader.html` changes.
- [ ] S0.6 [C] Verify **feature/payment propagation**: toggling a feature or payments in admin reaches a running app within ~60 s (timer + resume refresh in `lib/app/app.dart`); add a widget/provider test. Consider a `configVersion` field in `/features/me` + `/config/public` so the app can skip re-parsing unchanged data.
- [ ] S0.7 [C] Make `tool/verify.sh` (runs CLAUDE.md §6) so Michael can run it without Claude Code.

## S1 — Signing & release pipeline ⚠ (see PLAY_AND_DISTRIBUTION.md §2)
- [ ] S1.1 [M] Generate the release keystore (exact command in the doc), 2 offline backups, record the certificate SHA-256 + SHA-1 in the doc (fingerprints only — never the passwords).
- [ ] S1.2 [C] `android/key.properties` (git-ignored) + `key.properties.example`; `app/build.gradle.kts`: **release must fail if the key is missing** (remove the silent debug-key fallback) — keep an explicit `--dart-define`/Gradle property `ALLOW_DEBUG_SIGNING=true` for local `flutter run --release` only.
- [ ] S1.3 [C] Version scheme: `pubspec.yaml version: x.y.z+N`; N strictly increasing (also used as `versionCode`); document in the doc; `tool/bump_version.dart` helper.
- [ ] S1.4 [C] Production config: `API_BASE_URL` default is already prod; add `tool/build_release.sh` that runs verification, builds universal + per-ABI APKs, runs `apksigner verify --print-certs`, prints SHA-256/size. Release must not include: the `/dev/gallery` route (debug-only already — confirm), logging of tokens/bodies, debug banners. Review R8/shrink rules (`proguard-rules.pro`) so the WebView/TTS/Kotlin pieces survive minification — test a release APK on a real phone.
- [ ] S1.5 [C] Review `AndroidManifest.xml` + `network_security_config.xml` (cleartext only for 127.0.0.1/localhost — keep). Add `android:allowBackup` decision (recommend `false` or restricted backup rules because tokens live in secure storage).
- [ ] S1.6 [M] Install the signed APK on ≥3 real phones (different Android versions, incl. Samsung A175F); install **over** the previous build to prove updates work without uninstalling.

## S2 — Version management & in-app update prompt
- [ ] S2.1 [C] Server: `AppRelease` model + `GET /api/v1/app/version?versionCode=&platform=android` (public, cacheable 60 s) returning `{latestVersion, latestVersionCode, minSupportedVersionCode, updateAvailable, mandatory, downloadUrl, sha256, sizeBytes, releaseNotes, releasedAt}`; admin endpoints (permission `releases.write`) to create/publish/unpublish releases. Validation: https URL only, hostname allow-list from env `RELEASE_HOST_ALLOWLIST`. Unit + integration tests.
- [ ] S2.2 [C] Admin page **Releases** (list, create, mark latest, set minimum supported, mandatory toggle with plain-language explanation, release notes, checksum). Add to proxy whitelist + tests.
- [ ] S2.3 [C] App `UpdateService` (check at launch + on resume, throttled ≥6 h; sends `X-App-Version`/`X-App-Build` headers on all API calls too). Optional update → non-blocking banner/dialog "Update later / Update"; **mandatory** → full-screen blocking page with the download button. **Never interrupt an open reading session**: show prompts only on Home/Library (queue while the reader is open). Open the URL with `url_launcher` (external browser). No silent install, no `REQUEST_INSTALL_PACKAGES`. Show the checksum on the landing page, not in-app.
- [ ] S2.4 [C] Tests: version comparison edge cases, throttling, mandatory gate, offline/server-asleep behaviour (never block a user because the version server is unreachable).
- [ ] S2.5 [M] Publish release 1.0.0 in admin once S1+S3 are live.

## S3 — Landing page (Vercel) — see LANDING_PAGE_PLAN.md
- [ ] S3.1 [C] New `project/site/` (Next.js static/ISR, same toolchain as admin): download button, version/size/date/checksum from `GET /app/version`, release notes, install guide with Play-Protect / unknown-sources / Samsung Auto-Blocker steps, FAQ, QR code, links to `/privacy`, `/terms`, `/delete-account`.
- [ ] S3.2 [C] Pages `/privacy`, `/terms`, `/delete-account` (drafts; flagged "to be reviewed by Michael/lawyer").
- [ ] S3.3 [C] `render.yaml` buildFilters so API redeploys only for `server/**`; Vercel ignored-build-step docs for `admin` and `site`.
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
- [ ] S7.1 [C] **Account deletion**: server `DELETE /users/me` (password re-check; remove user, library/files in Cloudinary, annotations, bookmarks, progress, synced docs, features; keep anonymised payment records for accounting), in-app Profile → Delete account (typed confirmation), web `/delete-account` page + e-mail-confirmed request flow. Tests.
- [ ] S7.2 [C] Permission audit & flavor manifests (`direct` vs `play`), exact-alarm and foreground-service declarations text, remove unused permissions.
- [ ] S7.3 [C] `/play-audit` → `PLAY_READINESS.md`; fix items.
- [ ] S7.4 [C] Store listing text, short/long description, release notes, Data-safety answers, content-rating answers in `project/docs/store/`; screenshot plan (Michael captures).
- [ ] S7.5 [M] Play Console tasks (identity verification, app creation, declarations, closed test, merchant profile).

## S8 — Build flavors (`direct` / `play`) & AAB ⚠
- [ ] S8.1 [C] Gradle product flavors + `--dart-define=DISTRIBUTION=direct|play` exposed as `kDistribution`; `BillingPolicy` abstraction: `direct`→Paystack UI; `play`→consumption-only (no prices/CTAs/links; premium status display only).
- [ ] S8.2 [C] `flutter build appbundle --flavor play --release`; signing for upload key; document Play App Signing enrolment with the existing key (PEPK).
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
