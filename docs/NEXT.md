# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-06   **Current stage:** S0 — committed (`c613013`), waiting for Michael's Visual Studio C++ install
to run `flutter test`. Latest log: `sessions/2026-11-06-vs-tools.md` (section "WHERE WE STOPPED").

## Done
- Onboarding (2026-11-05): real layout (app = `project/mobile`), docs fixed, snapshot commit `160094b`.
- S0 (2026-11-05, committed 2026-11-06 as `c613013`, NOT pushed): server lint 0 errors; audit_dart fixed; `.gitignore`
  hardened; Expo files removed (tag `expo-legacy`, local); husky hook rewritten; `tool/verify.sh`; server e2e 22/22;
  reader harness 17/17; AccessRefreshScheduler + test (not run yet); `mobile/ios/` template restored.
- Last full check: `bash tool/verify.sh --e2e --reader` → all PASS except `app: flutter test` (needed VS C++).

## Half-done / in progress
- Michael is installing **Build Tools for Visual Studio 2026 → "Desktop development with C++"**.
- S0.6 test written, not run (needs VS C++).
- S0.2 DONE 2026-11-06: Paystack Test connection → "Connected. Paystack accepted the key." (403 gone; a real test payment is S10).

## Next 3 steps
1. After the install: new Git Bash → `flutter doctor` (Visual Studio ✓) → `cd project && bash tool/verify.sh --apk`.
2. If all PASS: tick S0.1 + S0.6 in ROADMAP, record the Flutter test count. Michael: merge the `chore/s0-baseline` pull request, push the tag (`git push origin expo-legacy`).
3. `/stage S1` (release signing — Michael creates the keystore with the command Claude Code gives).

## Open questions for Michael
- None blocking.

## Reminders
- All APKs so far are DEBUG-signed. Phones with a debug build must uninstall once when S1 lands (local-only books lost) — warn testers.
- To continue a conversation: `claude --continue` from the inner `Book-App` folder; or start `claude` and type `/resume`.
