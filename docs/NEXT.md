# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-06   **Current stage:** S1 — code done (S1.2–S1.5) on branch `feat/s1-release-signing`;
waiting for Michael: S1.1 (create the release key) and S1.6 (real phones). Latest log: `sessions/2026-11-06-s1-signing.md`.

## Done
- S0 complete (merged): all checks green, `flutter test` 202/202.
- S1.2–S1.5 (2026-11-06): release build fails without the key; `tool/build_release.sh`; `tool/bump_version.dart`;
  backup OFF; release logging debug-only. Tested with a throwaway key (deleted).

## Half-done / in progress
- S1.1 key created (fingerprints recorded). First signed build failed: keyPassword in `mobile/android/key.properties` wrong → Michael fixes, then rerun `bash tool/build_release.sh`.
- Pull request for `feat/s1-release-signing` waiting for Michael's merge.
- Michael to delete leftover test files (git-ignored): `mobile/build/release/` and `mobile/build/app/outputs/flutter-apk/app-*release.apk*`.

## Next 3 steps
1. Michael: merge the S1 pull request; Claude: `git switch main && git pull`.
2. Michael (S1.1): create the key with PLAY_AND_DISTRIBUTION.md §2.1, 2 offline backups, fill `mobile/android/key.properties`
   → `cd project/mobile && bash tool/build_release.sh` → send Claude the SHA-256/SHA-1 lines (not passwords) to record.
3. S1.6: uninstall old debug builds on test phones, install the new APK, then later install the next build over it. Then `/stage S2`.

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
