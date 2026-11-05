#!/bin/bash
# Restores the Android Gradle files Flutter generates (settings.gradle.kts, gradle.properties, wrapper…)
# when a build says:  "Task 'assembleRelease' not found in root project 'android'"
#                or:  "project 'app' not found in root project 'android'"
# Run from the Flutter project folder:   bash tool/fix_android.sh
set -e
cd "$(dirname "$0")/.."

if [ -f android/settings.gradle.kts ] || [ -f android/settings.gradle ]; then
  S=$(ls android/settings.gradle.kts android/settings.gradle 2>/dev/null | head -1)
  if grep -q 'include(":app")\|include(.:app.)\|include ":app"' "$S"; then
    echo "✓ $S already includes :app — the Gradle settings look fine."
    echo "  If the build still fails run:  flutter clean  and  cd android && ./gradlew projects"
    exit 0
  fi
  echo "✗ $S exists but does not include :app → adding it"
  echo 'include(":app")' >> "$S"
  echo "✓ added include(\":app\") to $S"
  exit 0
fi

echo "Android settings file is missing → asking Flutter to recreate the missing Android files…"
flutter create --platforms=android --org com.micbol --project-name readin_flutter .
# flutter create also adds a sample test and a sample MainActivity we do not want:
rm -f test/widget_test.dart
rm -rf android/app/src/main/kotlin/com/micbol/readin_flutter
echo
echo "✓ Done. Now run:  flutter clean && flutter pub get && flutter build apk --release --split-per-abi"
