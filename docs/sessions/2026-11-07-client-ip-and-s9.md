# 2026-11-07 — real client IP for rate limits, then S9.2 plan

## Checked (Michael: "is there anything I haven't done")
- All PRs merged (#12–#17). Site live with the 1.0.0 APK button; both APKs on GitHub match local SHA-256.
- Redis WORKS (RateLimit-Remaining counts down over IPv4).

## Found: rate-limit key = a proxy IP, not the user's
- Probing /config/public: counters keep restarting (`197/840` after `194/831`) → `req.ip` with `trust proxy 1` is one of
  several Render/Cloudflare edge addresses. Effect: many users share one counter (200/15 min general, 10 failed logins)
  → innocent users could get 429 once traffic grows; admin audit stores the proxy IP.
- Plan (branch `fix/real-client-ip`): `utils/clientIp.ts` — in production prefer `cf-connecting-ip` (set by Cloudflare,
  which fronts onrender.com, overwrites any client value) → `true-client-ip` → `req.ip`; validated with `net.isIP`.
  All limiters use `keyGenerator: ipKeyGenerator(clientIp(req))` (IPv6 /56 like the default); audit uses it too.
  One startup-time log line says WHICH source is used (never the IP). Outside production: `req.ip` only (no spoofing).
- Done: typecheck ✅ lint 0 errors ✅ unit (new tests/client-ip.test.mjs 6) ✅ e2e 29/29 ✅ (e2e = non-production → req.ip path).
- NOT tested: real Render headers. After deploy the log must show `[client-ip] using cf-connecting-ip …`; then re-probe:
  RateLimit-Remaining must count down steadily (no restarts at 199/900).

## S9.2 part A (approved by Michael 2026-11-07) — branch `feat/s9-premium-controls`
Plan: BillingConfig += `trialDays` (0=off), `reminders {enabled, steps[{offsetDays, inApp, email}]}` (default −5,−2,0,+3),
`marketing {headline, showPerDay, showSavings}`. Pure logic in billing.logic.ts: perDayText, savingsText (months =
round(days/30)), dueEmailReminder (one per run, latest due step, ≤2 days stale, key `offset@premiumUntilISO`), inAppReminder.
User += `premiumKind` ('paid'|'trial'|'gift'|null), `premiumTrialUsedAt`, `premiumRemindersSent: string[]`,
`emailReminders` (default true) — additive, no migration. New `/api/v1/billing`: GET /status, POST /trial (once per
account, atomic), PATCH /reminders {email}. Hourly in-process sweep e-mails due reminders (exactly once).
Admin Billing page: Free trial, Reminders, Hook text sections. Prices ₦700/30d + ₦7,000/365d are entered by Michael.
- Part A DONE: server (commit a62cfc4 + admin preview) and admin Billing page: new cards "Premium screen wording",
  "Free Premium trial", "Premium reminders" (+ "Send due reminders now"), plan rows show server-calculated hooks,
  quick-add buttons now ₦700/30 d and ₦7,000/365 d. Proxy ALLOWED + test: `billing/reminders/run`.
  Checks: server typecheck/lint/unit (35 new)/e2e 32 ✅; admin tsc ✅ lint 0 errors ✅ build ✅ proxy test ✅.
  NOT done: admin screenshots (needs a local server — ask Michael first). Admin Next 16.4.0 security warning at build
  (known, DECISIONS #19) → separate upgrade branch, ask Michael.
- Next: part B (app: Premium screen hooks + trial button, Home banner, Profile switch), part C (site prices).
- Part A merged (#19) and live: /config/public shows "less than ₦24 a day" + "2 months free · save ₦1,400".
- Part B (branch `feat/s9-app-premium`): models (perDayText, savingsText, trialDays, headline, reminders, BillingStatus,
  `premiumReminderFor` = server rule), ApiClient.patch, BillingApi.status/startTrial/setEmailReminders,
  billingStatusProvider; UpgradeScreen headline + hooks + `_TrialCard`; Home `PremiumReminderBanner` ("Later" hides
  until the next reminder day; only when billingVisibleProvider); Profile `ReminderEmailsRow`; icons gift/heart in shim.
  Checks: analyze ✅ flutter test 232 ✅ (+15 premium_controls_test) tap zones ✅ viewer ✅ audit ✅.
  NOT tested: real phone; UpgradeScreen trial card has no widget test (API + logic tested).
- Part C (branch `feat/s9-site-prices`): site Premium section (₦700 / ₦7,000, per-day hook, savings, trial line) baked at
  build + live refresh; server `/config/public` CORS `*` (e2e-checked). Found: Next 16 static export rejects a
  `no-store` fetch ("dynamic = error") → force-cache + `?build=` timestamp. Checks: site tsc/lint/build ✅,
  site_check 325 ✅, site_browser 16 ✅ (+2 pricing); server typecheck ✅ e2e 32 ✅.
- Admin screenshots (Michael approved a short local run): built admin + fake API + Edge at 1280/390 px, stopped after.
  Found 108 px sideways overflow on phones (grid items without min-w-0 + my 420 px unbreakable "Use recommended (…)"
  button) → `fix/admin-billing-phone-width`: 0 px both widths, no page errors.
- `chore/admin-next-upgrade`: next + eslint-config-next 16.4.0 → 16.4.3 (no download; site already had it); tsc/lint/
  build (security warning gone)/proxy test/browser login ✅.
