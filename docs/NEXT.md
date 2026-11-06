# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-06   **Current stage:** S1 — done except S1.6 (Michael tests the signed APK on phones). Payments blocked by
Paystack firewall (fix branch `fix/paystack-diagnostics`). Latest log: `sessions/2026-11-06-s1-signing.md`.

## Done
- S0 complete (merged): all checks green, `flutter test` 202/202.
- S1.2–S1.5 (2026-11-06): release build fails without the key; `tool/build_release.sh`; `tool/bump_version.dart`;
  backup OFF; release logging debug-only. Tested with a throwaway key (deleted).

## Half-done / in progress
- **Payments blocked**: Paystack firewall refuses POST /transaction/initialize from Render (HTML 403). Fix branch `fix/paystack-diagnostics` (better admin test, Ray ID in logs, kind app message, quiet Redis logs). Michael: deploy → admin Test connection → send Paystack support the Ray ID + Render IP ranges. Upstash Redis unreachable (rate limits off) → Michael checks Upstash + `UPSTASH_REDIS_URL`.
- S1.1 DONE: first release-signed APKs 1.0.0+1 built 2026-11-06 (`mobile/build/release/1.0.0+1/`, cert SHA-256 15b369e4…0810 ✓). Next: S1.6 phone test by Michael.

## Next 3 steps
1. Michael: merge `fix/paystack-diagnostics` → deploy on Render → admin Billing → Test connection → send Paystack support the
   Ray ID + Render outbound IP ranges (74.220.48.0/24, 74.220.56.0/24); keep Paystack's IP whitelist EMPTY. Check Upstash Redis.
2. Michael: S1.6 — uninstall old debug build, install `readin-1.0.0-arm64-v8a.apk`, test the main features, report.
3. Claude: S8 plan (play/direct flavors + AAB) for approval.

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
