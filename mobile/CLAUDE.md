# ReadIn app (`project/mobile`) — Flutter 3.47.6 / Dart 3.13.5, Android first (iOS template kept)

Read the root `CLAUDE.md` first. Pubspec name `readin_flutter`. Package/applicationId/namespace **`com.micbol.readin`** (never change).
This folder used to hold the old React-Native/Expo app; since commit `86582e4` it is the Flutter app. The unused
`linux/ macos/ web/ windows/` platform folders were removed (commit `160094b`). `ios/` was restored on 2026-11-05 at Michael's request to keep iPhone possible later: it is the untouched Flutter template (bundle id `com.example.readinFlutter`, display name "Readin Flutter") — choose the real bundle id in a future iOS stage (it is permanent once published). iOS needs Swift versions of the Kotlin features and a Mac + Apple Developer account.

## Commands (run from `project/mobile`)
```bash
flutter pub get
flutter analyze                    # must print "No issues found" (warnings count as failures)
flutter test                       # on Windows needs Visual Studio "Desktop development with C++" (pdfium_dart native hook)
node tool/test_tap_zones.js && node tool/test_viewer_core.js     # JS logic extracted from reader.html / viewer.html
python tool/audit_dart.py .                                      # fast static checks (imports, symbols, icons)
cd tool/reader_harness && pnpm install && pnpm test             # reader.html in the installed Edge/Chrome (17 tests)
flutter run --release -d <deviceId>
flutter build apk --release --split-per-abi     # needs android/key.properties (or -P ALLOW_DEBUG_SIGNING=true for a test build)
bash tool/build_release.sh                     # real release: checks + signed APKs + certificate check + notes
dart run tool/bump_version.dart patch          # raise version (versionCode +1)
bash tool/fix_android.sh           # only if Gradle says “project 'app' not found” (Android settings files lost)
```
`API_BASE_URL` build-time override: `--dart-define=API_BASE_URL=https://…/api/v1` (default = production API).

## Architecture
* `lib/main.dart` → `app/bootstrap.dart` → `app/app.dart` (ReadInApp: wake server, share-intent import queue, **45 s access refresh + on resume**, auto-open last book) → go_router (`core/services/router.dart`, `routes.dart`).
* State: Riverpod `StateNotifier`s per feature (`features/<name>/providers`). Storage: `core/services/storage_service.dart` (SharedPreferences keys `@readin/*`, `migrateReaderDefaults` version key) + `token_service.dart` (flutter_secure_storage).
* Network: Dio `core/api/api_client.dart` — attaches the bearer token, single-flight refresh on 401, returns `ApiResult<T>` (`dataOrNull`, `exceptionOrNull`). Endpoints in `api_endpoints.dart`. `LoggingInterceptor` logs method + URL only, and only in debug.
* **Local-first library**: imported files are stored under the app documents folder (`getApplicationDocumentsDirectory`) and synced (`features/import`, `features/library`); free-plan limit comes from the server (`publicConfigProvider`). Uninstalling the app deletes those files.
* **Reader** (`features/reader`): `ReaderServer` (loopback HTTP; serves `reader.html`, epub.js, jszip, the book, and **bundled fonts** at `/<token>/fonts/*.woff2`) + WebView (`epub_view.dart`) + `ReaderController` (prefs: font, size, weight, line-height, margin, align, hyphenate, flow, theme, pageAnim…). Typography is applied in `assets/reader/reader.html` (`applyTheme`); quick panel `reader_quick_settings.dart`, full panel `reader_settings_sheet.dart`. PDFs use `pdfrx`; other documents `features/documents` + `assets/reader/viewer.html`.
* **Entitlements**: `features/features` (`featuresProvider`, `habitsAccessProvider`, cache `@readin/features_cache`); **Billing**: `features/billing` (models, `publicConfigProvider`, `BillingApi`, Paystack WebView checkout `PaystackCheckoutScreen`, `refreshUserProvider`), UI `features/premium/screens/upgrade_screen.dart`; payment UI is shown only when `billingVisibleProvider` (admin switch) or the user is already Premium.
* Habits (`features/habits`) with native reminders (`android/.../HabitAlarms.kt`, inexact `setAndAllowWhileIdle`, boot receiver `HabitReceiver`) and cloud sync (`core/sync/doc_syncer.dart`, 409 merge). Read-aloud: `flutter_tts` + `ReadAloudService.kt` (foreground service, `mediaPlayback`). Share-intent import, folder scan, open/share file, volume-key paging: `MainActivity.kt` + `core/services/native_bridge.dart`, `volume_keys.dart`.
* "On this phone" scan (`features/device`) uses `MANAGE_EXTERNAL_STORAGE` — Google Play restricts this permission; plan: `direct` flavor only (S7.2/S8).
* Toasts: `widgets/app_toast.dart` (opaque). Dev gallery `/dev/gallery` is debug-only (`kDebugMode` in router). Google sign-in is switched off (`kGoogleSignInEnabled=false`).

## Conventions & gotchas
* Use `AppColors`, `AppTypography`, `PressableOpacity`, `AppToast`; icons only via `Ionicons.*` from `lib/constants/ionicons.dart`. The committed file is a hand-kept **Material-icon shim**; add a line there for a new icon name. `dart run tool/gen_ionicons.dart …` (see `COMMANDS.md`) can generate an exact Ionicons version locally — never commit that version.
* Adding a Riverpod provider that touches the network: write the test with `FakeAdapter` from `test/helpers/test_rig.dart`.
* `reader.html` changes: run `node tool/test_tap_zones.js` AND the browser harness `tool/reader_harness` (`pnpm test`; `READER_HTML=<file>` runs it against a copy). epub.js manager is async (`rendition.started.then`).
* Access refresh timing (45 s / on resume / ≥15 s gap / signed in only) lives in `lib/app/access_refresh.dart` (`AccessRefreshScheduler`, tested in `test/features/access_refresh_test.dart`).
* Android Gradle: git tracks `android/build.gradle.kts`, `android/app/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle.properties`, the wrapper properties and `android/app/src/**`; `local.properties`, `gradlew*`, `key.properties`, `*.jks`/`*.keystore` are git-ignored (`android/.gitignore`). Root `build.gradle.kts` forces `compileSdk=36` for plugin modules via reflection — leave it unless a plugin upgrade makes it unnecessary. Kotlin: `gradle.properties` has `android.builtInKotlin=false` and `settings.gradle.kts` declares the Kotlin Android plugin 2.4.0; AGP 9.1.0, Gradle 9.3.1.
* No `proguard-rules.pro` yet; release builds use R8 — test WebView/TTS/native channels in a release APK on a real phone.
* Backup is **off** (S1.5): `android:allowBackup="false"` + `res/xml/data_extraction_rules.xml` (no cloud backup, no device-to-device copy) because tokens in flutter_secure_storage cannot be decrypted on another phone.
* Release signing (S1): `android/key.properties` (copy `key.properties.example`) → release keystore. Without it a **release build fails** on purpose; test-only opt-out `-P ALLOW_DEBUG_SIGNING=true`. Real releases: `bash tool/build_release.sh` (checks + universal/per-ABI APKs + `apksigner` certificate check + notes in `build/release/<version>/`). Versions: `dart run tool/bump_version.dart patch|minor|major|build`. See `project/docs/PLAY_AND_DISTRIBUTION.md` §2–3.
* No new dependency without listing it in the stage plan (pub.dev package, why, size impact).
* Planned work touching this app: S1 signing, S2 update prompt, S4 biometrics (MainActivity → FlutterFragmentActivity), S6 Firebase, S7 account deletion/permissions, S8 flavors (`direct`/`play`). See `project/docs/ROADMAP.md`.
