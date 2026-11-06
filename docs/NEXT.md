# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-06   **Current stage:** S8 done (two versions: APK `direct` + Play `play` AAB) on `feat/s8-play-flavor`. Paystack (APK) paused —
firewall blocks Render; Play will use Google Play Billing (DECISIONS #16). Latest log: `sessions/2026-11-06-s1-signing.md`.

## Done
- S0 complete (merged): all checks green, `flutter test` 202/202.
- S1.2–S1.5 (2026-11-06): release build fails without the key; `tool/build_release.sh`; `tool/bump_version.dart`;
  backup OFF; release logging debug-only. Tested with a throwaway key (deleted).

## Half-done / in progress
- **Payments blocked**: Paystack firewall refuses POST /transaction/initialize from Render (HTML 403). Fix branch `fix/paystack-diagnostics` (better admin test, Ray ID in logs, kind app message, quiet Redis logs). Michael: deploy → admin Test connection → send Paystack support the Ray ID + Render IP ranges. Upstash Redis unreachable (rate limits off) → Michael checks Upstash + `UPSTASH_REDIS_URL`.
- S1.1 DONE: first release-signed APKs 1.0.0+1 built 2026-11-06 (`mobile/build/release/1.0.0+1/`, cert SHA-256 15b369e4…0810 ✓). Next: S1.6 phone test by Michael.

## Next 3 steps
1. Michael: merge `feat/s8-play-flavor` → deploy Render (server refuses Paystack from the Play version).
2. Michael: create the Play Console app (com.micbol.readin) + upload `readin-1.0.0-play.aab` to Closed testing ("use my own key"
   → PEPK steps from Claude); install the APK (S1.6) and report.
3. Claude: plan Google Play Billing (monthly + yearly via RevenueCat, DECISIONS #16), then S7.1 account deletion + S3 site.

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
