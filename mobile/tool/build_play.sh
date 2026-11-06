#!/usr/bin/env bash
# Builds the GOOGLE PLAY version (flavor "play") as an Android App Bundle (.aab) for upload
# to Play Console. (The APK for the website is tool/build_release.sh.)
#
#   bash tool/build_play.sh                # checks + AAB
#   bash tool/build_play.sh --skip-checks  # only when you ran tool/verify.sh just now
#
# Steps:
#   1. android/key.properties must exist (never printed). The bundle is signed with the UPLOAD key
#      (uploadStoreFile … in key.properties) or, if none is set, with the ReadIn release key.
#   2. App checks (project/tool/verify.sh --only mobile) unless --skip-checks.
#   3. flutter build appbundle --flavor play --release
#   4. Safety checks: signed with the upload/release key (never the debug key); the Play manifest
#      does NOT contain MANAGE_EXTERNAL_STORAGE (Google Play would reject it).
#   5. Copies it to build/release/<version>/readin-<version>-play.aab + notes (certificate, size, SHA-256).
set -uo pipefail

APP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT="$(cd "$APP/.." && pwd)"
SKIP_CHECKS=0
# ReadIn release certificate (PLAY_AND_DISTRIBUTION.md §2.2) and, once created, the upload certificate.
RELEASE_CERT="15b369e4c58910fba48a25f4e7be6db9497039e90727db7e56b43029c5090810"
UPLOAD_CERT="${READIN_UPLOAD_CERT:-}"
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

step "1/5 Keys"
[ -f android/key.properties ] || die "android/key.properties is missing (see project/docs/PLAY_AND_DISTRIBUTION.md §2)."
echo "android/key.properties found (contents not shown)."
VERSION_LINE=$(grep -E '^version:' pubspec.yaml | head -1 | tr -d '\r')
VERSION=${VERSION_LINE#version: }; VERSION=${VERSION// /}
NAME=${VERSION%%+*}; CODE=${VERSION##*+}
[[ "$NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$CODE" =~ ^[0-9]+$ ]] || die "pubspec.yaml version must look like 1.2.3+4 (found '$VERSION')."
echo "Version $NAME (versionCode $CODE). Play refuses a versionCode it has already seen — bump it for every upload."

step "2/5 App checks"
if [ $SKIP_CHECKS -eq 1 ]; then echo "Skipped (--skip-checks)."
else bash "$ROOT/tool/verify.sh" --only mobile || die "app checks failed — fix them first (logs: project/tool/.verify-logs/)."; fi

step "3/5 Build the Play bundle (this can take 10–20 minutes)"
AAB="$APP/build/app/outputs/bundle/playRelease/app-play-release.aab"
rm -f "$AAB"
flutter build appbundle --flavor play --release || die "AAB build failed."
[ -f "$AAB" ] || die "expected $AAB"

step "4/5 Safety checks"
KEYTOOL=""
for c in "${JAVA_HOME:-}/bin/keytool" "/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe" "$(command -v keytool 2>/dev/null)"; do
  [ -n "$c" ] && [ -f "$c" ] && KEYTOOL="$c" && break
done
[ -n "$KEYTOOL" ] || die "keytool not found (install Android Studio or a JDK)."
CERT_INFO=$("$KEYTOOL" -printcert -jarfile "$AAB" 2>&1) || die "could not read the bundle signature:
$CERT_INFO"
grep -qi 'CN=Android Debug' <<<"$CERT_INFO" && die "the bundle is signed with the DEBUG key. Do not upload it."
CERT=$(grep -m1 -E '^\s*SHA256:' <<<"$CERT_INFO" | sed 's/.*SHA256:[[:space:]]*//' | tr -d ':\r ' | tr 'A-F' 'a-f')
[[ "$CERT" =~ ^[0-9a-f]{64}$ ]] || die "could not read the bundle certificate SHA-256."
OWNER=$(grep -m1 -E '^\s*Owner:' <<<"$CERT_INFO" | sed 's/.*Owner:[[:space:]]*//' | tr -d '\r')
if [ "$CERT" = "$RELEASE_CERT" ]; then
  KIND="ReadIn RELEASE key (no upload key set — fine; Play App Signing: use this key)"
elif [ -n "$UPLOAD_CERT" ] && [ "$CERT" = "$UPLOAD_CERT" ]; then
  KIND="ReadIn UPLOAD key"
elif [ -z "$UPLOAD_CERT" ]; then
  KIND="an UPLOAD key not recorded yet — record its SHA-256 in PLAY_AND_DISTRIBUTION.md §2.2 and READIN_UPLOAD_CERT"
else
  die "the bundle is signed with an UNKNOWN key ($CERT). Check uploadStoreFile in android/key.properties."
fi
echo "Signed with: $KIND"
MANIFEST=$(find "$APP/build/app/intermediates" -path '*playRelease*' -name AndroidManifest.xml 2>/dev/null | grep -i 'merged_manifest' | head -1)
[ -n "$MANIFEST" ] || die "merged Play manifest not found under build/app/intermediates (cannot prove the permission is absent)."
# Match the real permission entry, not the word (comments mention it).
grep -q 'android:name="android.permission.MANAGE_EXTERNAL_STORAGE"' "$MANIFEST" && die "the Play manifest contains MANAGE_EXTERNAL_STORAGE — Google Play would reject it."
echo "Play manifest has no MANAGE_EXTERNAL_STORAGE ($MANIFEST)."

step "5/5 Copy + notes"
DEST="$APP/build/release/$NAME+$CODE"
mkdir -p "$DEST"
TARGET="$DEST/readin-$NAME-play.aab"
cp "$AAB" "$TARGET"
NOTES="$DEST/PLAY-NOTES-$NAME+$CODE.txt"
{
  echo "ReadIn $NAME (versionCode $CODE) — Google Play bundle — built $(date '+%Y-%m-%d %H:%M')"
  echo "Package: com.micbol.readin   Flavor: play"
  echo "Signer: $OWNER"
  echo "Signer SHA-256: $CERT"
  echo "Signed with: $KIND"
  echo "File: $(basename "$TARGET")   Size: $(awk -v b="$(wc -c <"$AAB")" 'BEGIN{printf "%.1f MB", b/1048576}')   SHA-256: $(sha256sum "$AAB" | cut -d' ' -f1)"
  echo
  echo "Upload in Play Console → your app → Test and release → (Closed testing) → Create new release."
  echo "FIRST upload only: App signing → choose \"Use my own key\" and upload the ReadIn RELEASE key via PEPK"
  echo "(see PLAY_AND_DISTRIBUTION.md §2.3) — then APK users can move to Play without uninstalling."
} >"$NOTES"
echo; cat "$NOTES"; echo; echo "DONE → $TARGET"
