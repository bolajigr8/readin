# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-07   **Current stage:** Group B — 1.0.1 built, S2 + S4 done, waiting for merge (order below).
Latest log: `sessions/2026-11-07-release-s2-s4.md`.

## Done
- S0, S1 (except S1.6 phone test), S8 two versions (merged). Release key + first signed APKs/AAB 1.0.0+1.
- S7.1 delete my account (PR #10) and the first S3 site (PR #11) — merged.

## Half-done / in progress
- Paystack (APK) paused: Paystack's firewall blocks Render (support contacted 2026-11-06). Play will use Google Play Billing (DECISIONS #16).
- Redis (Upstash): WORKING since 2026-11-06 (fix/redis-upstash merged; live RateLimit-Remaining counts down). `fix/redis-startup-race`
  removes the false "Redis unavailable" line at boot — waiting for merge.

## Waiting for Michael's merge — IN THIS ORDER
1. `chore/release-1.0.1` (version 1.0.1+2; files in mobile/build/release/1.0.1+2/, checksums in RELEASE-NOTES).
2. `feat/s2-update-prompt` (server /app/version + admin "App versions" + app banner / required-update screen; contains 1).
3. `feat/s4-biometric-unlock` (fingerprint/face; contains 1 + 2). Then I build 1.0.2 (S2 + S4) for the phone test.
- Michael: GitHub release v1.0.1 (upload 1.0.1 APKs) → I update site/public/release.json; after S2 is live add the
  version in admin → App versions. Phone test list for S4 is in the session log (MainActivity changed).
- Open: Render log `[client-ip] using …` · iPhone web app (S11) parked by Michael (iPhones can't use Google Play).

## Next 3 steps
1. ✅ S7.1 built — Michael: merge `feat/s7-account-deletion` + deploy Render; try Profile → Delete account with a TEST account.
2. ✅ S3 site built (branch `feat/s3-landing-site`, includes S7.1) — Michael: merge + Cloudflare Pages + Spaceship DNS (steps in LANDING_PAGE_PLAN). S7.4 + S7.2 also done (docs/store/PLAY_CONSOLE_ANSWERS.md). Group A coding COMPLETE.
3. Michael: then create the Play Console app → "use my own key" (Claude gives PEPK steps) → closed test, 12+ testers, 14 days.
Order agreed 2026-11-06: Group A (S7.1, S3, S7.4, S7.2) → upload + closed test → Group B during the test (Play Billing monthly+yearly,
S2 update prompt, S4 biometrics, S6 Firebase, S5 roles, S9, Paystack phone-side fix) → Group C (S7.3 play-audit, S10 QA) → production.

## REMIND MICHAEL (open tasks — mention the relevant ones at each step)
- (done 2026-11-06: S8 merged, Paystack message sent.) Merge `feat/s3-landing-site` (contains S7.1 too) + deploy Render.
- S1.6 phone test of `mobile/build/release/1.0.0+1/readin-1.0.0-arm64-v8a.apk` (uninstall old build first).
- Collect 12+ testers' Gmail addresses. Optional upload key (`readin-upload.jks`, alias upload) + key.properties lines.
- NOT uploading to Play yet (Michael, 2026-11-06) — remind when Group A is done: create app (Free, App), PEPK "use my own key".
- Later: merchant profile (USD domiciliary account), monthly+yearly subscriptions, RevenueCat account; Vercel site project;
  domain?; Resend domain verification; Firebase project; Paystack live keys.
- Decisions pending: free trial for Premium (yes/no, days). Prices: ₦700/month, ₦7,000/year (Michael 2026-11-07; enter them in admin → Billing).
- Website LIVE 2026-11-07: readin.micbol.org (Cloudflare Pages, auto-deploys from main). APK hosting: github.com/bolajigr8/readin-releases (tag v1.0.0) → then fill site/public/release.json.

## NEW 2026-11-06: Michael has a Google Play Console account → Play is the main goal (APK stays)
Verified requirements: PLAY_AND_DISTRIBUTION.md §7b. Order APPROVED by Michael (DECISIONS #15):
1. S1.1 key (now urgent: needed for the AAB + "use my own key" in Play App Signing) → S1.6.
2. "Play-ready minimum" before the closed test: S8.1/S8.2 (play flavor: no Paystack/prices, no MANAGE_EXTERNAL_STORAGE; AAB),
   S7.1 account deletion (app + server), S3 site with /privacy, /terms, /delete-account, S7.4 store listing + Data safety +
   content rating answers, reviewer account.
3. Closed test: 12+ testers for 14 days in a row (personal account) — S2/S4/S6 continue during those 14 days.
4. Apply for production.

## Open questions for Michael
- None. Answers 2026-11-06: order OK; Play account is personal; Michael will find 12+ testers.

## Reminders
- Phones with an old debug build must uninstall once (local-only books on that phone are lost) — warn testers.
- `flutter run --release` / `flutter build apk --release` now need the key, or `-P ALLOW_DEBUG_SIGNING=true` for tests.
- To continue a conversation: `claude --continue` from the inner `Book-App` folder; or start `claude` and type `/resume`.
