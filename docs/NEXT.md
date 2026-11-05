# NEXT — where we are right now (Claude Code keeps this current)

**Updated:** 2026-11-05 (late)   **Current stage:** S0 done except S0.2 (Michael) and running the S0.6 test (needs VS C++). Log: `sessions/2026-11-05-s0.md`.

## Done
- Onboarding (log `sessions/2026-11-05-onboarding.md`): layout verified (app = `project/mobile`), docs fixed, snapshot commit `160094b`.
- `mobile/ios/` restored (Michael's request — keep iPhone possible; template only).
- S0.1 server lint 0 errors (was 1145); audit_dart works on Windows, 0 problems.
- S0.3 `.gitignore` hardened; tag `expo-legacy`; Expo files removed; husky hook rewritten and tested; README rewritten;
  Dockerfile pins pnpm 10.28.1; render.yaml + 5 env names; `.env.example` cleaned.
- S0.4 server e2e `pnpm run test:e2e` — 22/22 (in-memory MongoDB, fake Paystack/Resend, Redis down).
- S0.5 reader harness `mobile/tool/reader_harness` — 17/17 in Edge.
- Final `bash tool/verify.sh --e2e --reader`: all PASS except `flutter test` (VS C++).
- S0.7 `tool/verify.sh` (+ `--apk --e2e --reader --only`).

## Half-done / in progress
- S0.6 propagation test written + analyze-clean, **not run** (needs VS C++ for `flutter test`).
- S0.2 Paystack 403 — waits for Michael (deploy + Billing → Test connection).
- S0 committed on 2026-11-06 by Claude Code at Michael's request (see `git log`); NOT pushed — Michael pushes.

## Next 3 steps
1. Michael: install VS 2022 "Desktop development with C++" → `bash tool/verify.sh` (runs the new access_refresh test too).
2. Michael: review + commit S0; push; deploy server; Billing → Test connection; paste the result line (never the key).
3. Then `/stage S1` (signing — needs Michael to create the keystore).

## Open questions for Michael
- None blocking.

## Reminders
- All APKs so far are DEBUG-signed. Phones with a debug build must uninstall once when S1 lands (local-only books lost) — warn testers.
- Push the new tag too: `git push origin expo-legacy`.
