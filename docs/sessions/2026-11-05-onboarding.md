# 2026-11-05 — onboarding (first Claude Code session)
Stage: pre-S0 (learn project, baseline, fix doc paths)        Started from: NEXT.md as of the context pack (not started)

## Asked
Michael's first prompt: learn the whole project read-only, verify the docs against the real code/layout, run the
full baseline, report risks, propose the S0 plan; after approval fix every doc path, create this log, update NEXT.md,
run /handoff. No code changes this session.

## Decided (also copied to DECISIONS.md)
- The Flutter app lives in `project/mobile` (not `flutter/readin_flutter`). The old Expo app is gone from `mobile/`;
  only small Expo leftovers remain at the repo root.
- Snapshot commit of all uncommitted v4–v9 work made by Claude Code (done: `160094b`).
- Expo leftovers: tag `expo-legacy`, then delete (S0.3).
- Husky pre-commit hook: rewrite (server lint-staged + typecheck; admin tsc when admin staged; flutter analyze when
  mobile staged) (S0.3).

## Changed (files / areas)
- git: commit `160094b` "chore: snapshot of v9 app, server v7 and admin v2 work before S0"
  (67 added, 148 deleted = unused ios/linux/macos/web/windows folders, 98 modified). Secret-file check on the staged
  list: none. `lib/constants/ionicons.dart` included: it is the hand-kept Material shim (+10 icon names used by new screens).
- Docs/paths: see "Doc fixes" below (filled in as they are done).

## Tested (commands + results)
Before approval (read-only, Node 24.13 / pnpm 10.28.1 / Python 3.14.2 / Flutter 3.47.6 / Dart 3.13.5 / Java 25):
| Suite | Result |
|---|---|
| server `pnpm run typecheck` | PASS |
| server `pnpm run lint` | FAIL 1145 errors / 241 warnings — 1137 errors are `dist/` (ignore pattern not global); real: `calibre.service.ts:29,53` preserve-caught-error, tests `console` no-undef ×6 |
| server tests | PASS billing 10, entitlements 14, revenuecat 8 = 32 |
| admin `npx tsc --noEmit` | PASS |
| admin `pnpm run lint` | PASS, 1 warning `src/lib/api.ts:46` |
| admin proxy-utils test | PASS 7 |
| `flutter analyze` | No issues found |
| `node tool/test_tap_zones.js` / `test_viewer_core.js` | PASS 4 / 9 |
| `python tool/audit_dart.py .` | CRASH on Windows console (`UnicodeEncodeError` '✗'); with `PYTHONIOENCODING=utf-8`: 185 files, 1 problem `Ionicons._ missing from the icon file` |
After approval (these write build output, so they waited for approval):
| Suite | Result |
|---|---|
| server `pnpm install` | OK (pnpm says some dependency build scripts are not approved — `pnpm approve-builds`; tests unaffected) |
| admin `pnpm install` + `pnpm build` | PASS (Next 16.4.0 Turbopack, 13 routes) |
| `flutter pub get` | OK, `pubspec.lock` unchanged |
| `flutter test` | FAIL before any test runs: `Building assets for package:pdfium_dart failed … No compiler configured on host 'windows_x64'` → install the VS 2022 "Desktop development with C++" workload |
| `flutter build apk --release --split-per-abi` | PASS in 1306 s: arm64-v8a 33.0 MB, armeabi-v7a 28.8 MB, x86_64 34.8 MB — **debug-signed** (no key.properties) |
Build warnings worth tracking: `flutter_tts` applies the Kotlin Gradle Plugin ("future versions of Flutter will fail to
build") → check for a newer flutter_tts before the next Flutter upgrade; "Expected to find fonts for CupertinoIcons" —
not used in `lib/`, comes from a package/framework widget (check for a blank icon on a real phone); Java "source/target
value 8 is obsolete" from a plugin (harmless).

## Doc fixes (Step 7)
- `Book-App/CLAUDE.md`: folder map (app = `project/mobile`, Expo leftovers), §4 app path, §5 Ionicons shim truth,
  §6 app path + UTF-8 audit + known baseline, §7 Gradle files now tracked.
- `project/mobile/CLAUDE.md` created (moved + corrected from `flutter/readin_flutter/CLAUDE.md`, which was deleted with
  the empty `flutter/` folders — outside git).
- `Book-App/README.md`, `.claude/commands/{verify-all,release-apk,resume}.md` paths.
- `project/docs`: ROADMAP (S0.1 baseline, S0.3 rewritten, S0.5 path), HISTORY (paths, Ionicons state), MANUAL_TASKS,
  PLAY_AND_DISTRIBUTION §2.2, DECISIONS (open item resolved, decisions 8–11), FIRST_PROMPT (real folder), NEXT.
- `project/server/CLAUDE.md`: lint failure note, render.yaml/.env.example/Dockerfile gaps.

## Not done / not tested
- `flutter test` (needs VS C++), real phone, Paystack live, Render/Vercel consoles.
- No code changed. Doc changes not committed (Michael commits).

## Suggested commit (Michael, in `project/`)
`git add docs server/CLAUDE.md mobile/CLAUDE.md && git commit -m "docs: fix paths to real layout (app in mobile/), onboarding session log"`
(`Book-App/CLAUDE.md`, `README.md` and `.claude/` are outside the git repo.)

## Next step
Michael installs the VS C++ workload and says go for `/stage S0`.
