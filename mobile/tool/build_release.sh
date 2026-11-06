#!/usr/bin/env bash
# Builds the APKs you give to users, signed with the ReadIn RELEASE key.
#
#   bash tool/build_release.sh                # checks + universal APK + per-ABI APKs
#   bash tool/build_release.sh --skip-checks  # only when you ran tool/verify.sh just now
#
# Run from project/mobile (or anywhere: it finds its own folder). Steps:
#   1. android/key.properties must exist (it is never printed).
#   2. All app checks (project/tool/verify.sh --only mobile) unless --skip-checks.
#   3. flutter build apk --release (universal) and --split-per-abi.
#   4. apksigner verify --print-certs on every APK; stops if one is signed with the
#      debug key or with a different certificate than the others.
#   5. Copies the APKs to build/release/<version>/ with a notes file:
#      version, versionCode, certificate SHA-256, file sizes and SHA-256 checksums.
set -uo pipefail

APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$APP/.." && pwd)"
SKIP_CHECKS=0
for a in "$@"; do
  case "$a" in
    --skip-checks) SKIP_CHECKS=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a"; exit 64 ;;
  esac
done

die() { echo; echo "STOPPED: $*"; exit 1; }
step() { echo; echo "== $* =="; }

cd "$APP" || die "cannot open $APP"

# ── 1. key present ────────────────────────────────────────────────────────────
step "1/5 Release key"
[ -f android/key.properties ] || die "android/key.properties is missing.
Create the release key first (project/docs/PLAY_AND_DISTRIBUTION.md §2.1),
then copy android/key.properties.example to android/key.properties and fill it in."
echo "android/key.properties found (contents not shown)."

VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -1 | tr -d '\r')
VERSION=${VERSION_LINE#version: }
VERSION=${VERSION// /}
NAME=${VERSION%%+*}
CODE=${VERSION##*+}
[[ "$NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$CODE" =~ ^[0-9]+$ ]] \
  || die "pubspec.yaml version must look like 1.2.3+4 (found '$VERSION')."
echo "Version $NAME (versionCode $CODE)."

# ── 2. checks ─────────────────────────────────────────────────────────────────
step "2/5 App checks"
if [ $SKIP_CHECKS -eq 1 ]; then
  echo "Skipped (--skip-checks)."
else
  bash "$ROOT/tool/verify.sh" --only mobile || die "app checks failed — fix them first (logs: project/tool/.verify-logs/)."
fi

# ── 3. build ──────────────────────────────────────────────────────────────────
step "3/5 Build (this can take 10–25 minutes)"
OUT="$APP/build/app/outputs/flutter-apk"
rm -f "$OUT"/app-*release.apk "$OUT"/app-*release.apk.sha1 2>/dev/null
flutter build apk --release || die "universal APK build failed."
flutter build apk --release --split-per-abi || die "per-ABI APK build failed."
shopt -s nullglob
APKS=("$OUT"/app-release.apk "$OUT"/app-*-release.apk)
shopt -u nullglob
[ ${#APKS[@]} -ge 2 ] || die "expected APKs in $OUT, found ${#APKS[@]}."

# ── 4. signature check ────────────────────────────────────────────────────────
step "4/5 Signature check"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$SDK" ] && [ -f android/local.properties ]; then
  SDK=$(grep -E '^sdk.dir=' android/local.properties | head -1 | cut -d= -f2- | tr -d '\r' | sed 's/\\\\/\//g; s/\\:/:/g')
fi
[ -n "$SDK" ] || SDK="$LOCALAPPDATA/Android/Sdk"
BT=$(ls -d "$SDK"/build-tools/*/ 2>/dev/null | sort -V | tail -1)
APKSIGNER=""
for c in "${BT}apksigner.bat" "${BT}apksigner"; do [ -f "$c" ] && APKSIGNER="$c" && break; done
[ -n "$APKSIGNER" ] || die "apksigner not found under $SDK/build-tools (install Android SDK Build-Tools)."

FIRST_CERT=""
for apk in "${APKS[@]}"; do
  certs=$("$APKSIGNER" verify --print-certs "$apk" 2>&1) || die "apksigner rejected $(basename "$apk"):
$certs"
  if grep -qi 'CN=Android Debug' <<<"$certs"; then
    die "$(basename "$apk") is signed with the DEBUG key. Do not give it to anyone."
  fi
  # apksigner prints e.g. "V2 Signer: certificate SHA-256 digest: a3b1…" (one line per scheme).
  cert=$(grep -m1 -i 'certificate SHA-256 digest:' <<<"$certs" | sed 's/.*digest:[[:space:]]*//' | tr -d '\r ')
  [[ "$cert" =~ ^[0-9a-f]{64}$ ]] || die "could not read the certificate SHA-256 of $(basename "$apk")."
  if [ -z "$FIRST_CERT" ]; then
    FIRST_CERT="$cert"
    SHA1=$(grep -m1 -i 'certificate SHA-1 digest:' <<<"$certs" | sed 's/.*digest:[[:space:]]*//' | tr -d '\r ')
    DN=$(grep -m1 -i 'certificate DN:' <<<"$certs" | sed 's/.*certificate DN:[[:space:]]*//' | tr -d '\r')
  elif [ "$cert" != "$FIRST_CERT" ]; then
    die "$(basename "$apk") has a different certificate than the others."
  fi
  echo "OK  $(basename "$apk")"
done

# ── 5. copy + notes ───────────────────────────────────────────────────────────
step "5/5 Copy + notes"
DEST="$APP/build/release/$NAME+$CODE"
mkdir -p "$DEST"
NOTES="$DEST/RELEASE-NOTES-$NAME+$CODE.txt"
{
  echo "ReadIn $NAME (versionCode $CODE) — built $(date '+%Y-%m-%d %H:%M')"
  echo "Package: com.micbol.readin"
  echo "Certificate: $DN"
  echo "Certificate SHA-256: $FIRST_CERT"
  echo "Certificate SHA-1:   $SHA1"
  echo
  echo "File                                  Size (MB)   SHA-256"
} >"$NOTES"
for apk in "${APKS[@]}"; do
  base=$(basename "$apk" .apk)
  abi=${base#app-}; abi=${abi%-release}; [ "$abi" = "release" ] && abi="universal"
  [ "$base" = "app-release" ] && abi="universal"
  target="readin-$NAME-$abi.apk"
  cp "$apk" "$DEST/$target"
  size=$(awk -v b="$(wc -c <"$apk")" 'BEGIN{printf "%.1f", b/1048576}')
  sum=$(sha256sum "$apk" | cut -d' ' -f1)
  printf '%-37s %-11s %s\n' "$target" "$size" "$sum" >>"$NOTES"
done
{
  echo
  echo "Which file? Most phones: arm64-v8a. Very old phones: armeabi-v7a. Not sure: universal (bigger)."
} >>"$NOTES"

echo
cat "$NOTES"
echo
echo "DONE → $DEST"
echo "Check: the certificate SHA-256 above must match the one recorded in project/docs/PLAY_AND_DISTRIBUTION.md §2.2."
