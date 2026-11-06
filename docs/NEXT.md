# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-06   **Current stage:** S1 — code done (S1.2–S1.5) on branch `feat/s1-release-signing`;
waiting for Michael: S1.1 (create the release key) and S1.6 (real phones). Latest log: `sessions/2026-11-06-s1-signing.md`.

## Done
- S0 complete (merged): all checks green, `flutter test` 202/202.
- S1.2–S1.5 (2026-11-06): release build fails without the key; `tool/build_release.sh`; `tool/bump_version.dart`;
  backup OFF; release logging debug-only. Tested with a throwaway key (deleted).

## Half-done / in progress
- Pull request for `feat/s1-release-signing` waiting for Michael's merge.
- Michael to delete leftover test files (git-ignored): `mobile/build/release/` and `mobile/build/app/outputs/flutter-apk/app-*release.apk*`.

## Next 3 steps
1. Michael: merge the S1 pull request; Claude: `git switch main && git pull`.
2. Michael (S1.1): create the key with PLAY_AND_DISTRIBUTION.md §2.1, 2 offline backups, fill `mobile/android/key.properties`
   → `cd project/mobile && bash tool/build_release.sh` → send Claude the SHA-256/SHA-1 lines (not passwords) to record.
3. S1.6: uninstall old debug builds on test phones, install the new APK, then later install the next build over it. Then `/stage S2`.

## Open questions for Michael
- None blocking.

## Reminders
- Phones with an old debug build must uninstall once (local-only books on that phone are lost) — warn testers.
- `flutter run --release` / `flutter build apk --release` now need the key, or `-P ALLOW_DEBUG_SIGNING=true` for tests.
- To continue a conversation: `claude --continue` from the inner `Book-App` folder; or start `claude` and type `/resume`.
