#!/usr/bin/env bash
# ReadIn — run every check (server, admin, app) and print a pass/fail table.
# Usage (Git Bash, from anywhere):
#   bash tool/verify.sh            # all checks
#   bash tool/verify.sh --apk      # + release APK build (slow: up to ~20 min the first time)
#   bash tool/verify.sh --e2e      # + server end-to-end tests (downloads MongoDB once, ~650 MB on Windows)
#   bash tool/verify.sh --reader   # + reader.html browser tests (uses the installed Edge/Chrome)
#   bash tool/verify.sh --only server|admin|mobile|site
# It never stops at the first failure. Full logs: tool/.verify-logs/ (git-ignored).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS="$ROOT/tool/.verify-logs"
mkdir -p "$LOGS"
APK=0; E2E=0; READER=0; ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --apk) APK=1 ;;
    --e2e) E2E=1 ;;
    --reader) READER=1 ;;
    --only) ONLY="${2:-}"; shift ;;
    *) echo "unknown option: $1"; exit 2 ;;
  esac
  shift
done

ROWS=()
FAILED=0

# run <name> <dir> <command…>  — runs in <dir>, logs to $LOGS/<name>.log
run() {
  local name="$1" dir="$2"; shift 2
  local log="$LOGS/${name//[^A-Za-z0-9_.-]/_}.log"
  printf '… %-28s' "$name"
  ( cd "$ROOT/$dir" && "$@" ) >"$log" 2>&1
  local code=$?
  local tests
  tests=$(count_tests "$log")
  if [ $code -eq 0 ]; then
    echo " PASS"
    ROWS+=("$(printf '%-28s | PASS   | %-6s |' "$name" "$tests")")
  else
    FAILED=1
    local first
    first=$(grep -m1 -iE 'error|fail|✗|not ok|exception' "$log" | tr -d '\r' | cut -c1-110)
    if grep -q "No compiler configured on host 'windows" "$log"; then
      first="needs Visual Studio 2022 'Desktop development with C++' (pdfium_dart native build)"
    fi
    echo " FAIL  (log: tool/.verify-logs/$(basename "$log"))"
    ROWS+=("$(printf '%-28s | FAIL   | %-6s | %s' "$name" "$tests" "${first:-exit code $code}")")
  fi
}

# Best-effort test count from a log.
count_tests() {
  local log="$1" n
  n=$(grep -oE '^[0-9]+ tests passed' "$log" | awk '{s+=$1} END {if (s) print s}')
  [ -z "$n" ] && n=$(grep -oE '\+[0-9]+(: All tests passed| ~[0-9]+: All tests passed)' "$log" | tail -1 | grep -oE '^\+[0-9]+' | tr -d '+')
  [ -z "$n" ] && n=$(grep -oE '^ok - ' "$log" | wc -l | awk '$1>0{print $1}')
  echo "${n:--}"
}

server_unit_tests() {
  local code=0 t
  for t in tests/*.test.mjs; do
    echo "### $t"
    node --experimental-strip-types --no-warnings "$t" || code=1
  done
  return $code
}

want() { [ -z "$ONLY" ] || [ "$ONLY" = "$1" ]; }

if want server; then
  run "server: install"   server pnpm install --frozen-lockfile
  run "server: typecheck" server pnpm run typecheck
  run "server: lint"      server pnpm run lint
  run "server: unit tests" server server_unit_tests
  if [ $E2E -eq 1 ]; then
    run "server: e2e tests" server pnpm run test:e2e
  fi
fi

if want admin; then
  run "admin: install"    admin pnpm install --frozen-lockfile
  run "admin: tsc"        admin pnpm exec tsc --noEmit
  run "admin: lint"       admin pnpm run lint
  run "admin: build"      admin pnpm build
  run "admin: proxy test" admin node --experimental-strip-types --no-warnings tests/proxy-utils.test.mjs
fi

if want mobile; then
  run "app: pub get"      mobile flutter pub get
  run "app: analyze"      mobile flutter analyze
  run "app: flutter test" mobile flutter test
  run "app: tap zones"    mobile node tool/test_tap_zones.js
  run "app: viewer core"  mobile node tool/test_viewer_core.js
  run "app: audit_dart"   mobile python tool/audit_dart.py .
  if [ $READER -eq 1 ]; then
    run "app: reader install" mobile/tool/reader_harness pnpm install --frozen-lockfile
    run "app: reader browser" mobile/tool/reader_harness node harness.mjs
  fi
  if [ $APK -eq 1 ]; then
    # This is only a "does it build" check. Without android/key.properties the release
    # build would stop on purpose (S1), so we allow the debug key here explicitly.
    # Real releases: bash mobile/tool/build_release.sh (refuses the debug key).
    if [ -f "$ROOT/mobile/android/key.properties" ]; then
      run "app: release APK" mobile flutter build apk --flavor direct --release --split-per-abi
    else
      run "app: release APK (debug key)" mobile flutter build apk --flavor direct --release --split-per-abi -P ALLOW_DEBUG_SIGNING=true
      echo "NOTE: android/key.properties is missing — this APK is signed with the DEBUG key (do not give it to users)."
    fi
  fi
fi

if want site; then
  run "site: check"       . node tool/site_check.mjs
  if [ $READER -eq 1 ]; then
    run "site: browser"     . node tool/site_browser.mjs
  fi
fi

echo
printf '%-28s | %-6s | %-6s | %s\n' "suite" "result" "tests" "first error line"
printf -- '-----------------------------+--------+--------+------------------------\n'
for r in "${ROWS[@]}"; do echo "$r"; done
echo
if [ $FAILED -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "SOME CHECKS FAILED — see tool/.verify-logs/"; fi
exit $FAILED
