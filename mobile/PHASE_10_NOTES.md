# ReadIn Flutter — Phase 10 (Audio/TTS · Upgrade · polish · release)

Apply on top of Phases 1–9: unzip over the project root, then
```
flutter pub get          # adds flutter_tts (+ dev: flutter_launcher_icons, flutter_native_splash)
dart run flutter_launcher_icons          # RN icon + adaptive icon (bg #0A0A0A)
dart run flutter_native_splash:create    # dark #0A0A0A splash with the RN splash icon
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
Delete from your project: `lib/features/placeholder/` (the folder is gone — both remaining placeholder files were replaced).

## What was added
| Area | Files |
|---|---|
| TTS | `features/audio/data/tts_engine.dart` (`TtsEngine` + `FlutterTtsEngine`), `providers/audio_controller.dart` (`AudioController`, `splitIntoChunks`, speed helpers) |
| UI | `features/audio/screens/audio_player_screen.dart`, `widgets/mini_player.dart`, `widgets/audio_cover.dart` |
| Upgrade | `features/premium/{data/premium_service.dart, providers/premium_providers.dart, screens/upgrade_screen.dart}` |
| Push (stub) | `core/services/notification_service.dart` (no-op; see below) |
| Wiring | `home_shell.dart` (mini player), `book_detail_screen.dart` (**Listen Preview** enabled), router (real `/audio-player` + `/upgrade`) |
| Polish | text-scale clamp 0.9–1.2, haptic on tab change, TalkBack labels on all icon-only buttons (`PressableOpacity.semanticLabel`), dev tools hidden in release builds, release signing, icons + splash config, TTS package-visibility entry in the manifest |

## Audio (TTS)
* **Listen Preview** on the book detail (any Gutenberg book): builds the RN text (`"<title> by <Author>. <subjects>."`), loads it into the **app-lifetime** `audioControllerProvider` and opens the player (does not auto-start).
* Text is split into sentence-packed chunks (≤ 300 chars, `(?<=[.!?])\s+`, fragments ≤ 5 chars dropped — RN `splitIntoChunks`). Speed 0.75 / 1 / 1.25 / 1.5 / 2 → engine rate `0.5 × speed`. Each finished chunk auto-advances; the last one rewinds and closes the mini player. **Pause** = stop + replay of the current chunk (Android has no real pause); stale completion callbacks are ignored.
* **Fix vs RN:** RN showed a *sentence* count next to a *chunk* index; both are chunk-based here ("N sentences" label kept as in RN).
* **Mini player:** floats **above the tab bar** (RN placed it at `inset + 8`, i.e. on top of the tab bar). Visible on the four tabs; it is part of the tab shell, so it is hidden while a pushed screen (book detail, reader…) is open — the audio keeps playing.
* Full player: header "NOW LISTENING", 220 cover with colour glow, title 22 Bold, "Text-to-speech preview", 4 px progress + counters, speed chips, skip ±5, 72 px play button with glow, "Stop & Close".

## Upgrade
* UI per UI_SPEC §4.16: hero, comparison table (6 rows: Unlimited books · Annotations · Offline reading · Audio TTS · Advanced stats · Priority support), Monthly $4.99 / **Annual $39.99 "Save 33%"** (pre-selected), amber **Start Premium**, **Restore Purchases**, legal text.
* **Purchases are fake by default** (decision in the tracker): `FakePremiumService` returns `unavailable` → toast "Purchase flow available in production build." (RN dev-build behaviour). Entry points: Profile → Subscription, drawer upgrade card (goes to Profile like RN), the 403 dialogs (library limit, annotation limit).
* **Real purchases later** — implement `PremiumService` (`purchase(packageId)`, `restore()`) with `purchases_flutter`, entitlement id `premium`, SDK key via `--dart-define=REVENUECAT_KEY=…`, and override `premiumServiceProvider`. The server flips `plan` through the RevenueCat webhook; there is **no `GET /auth/me`**, so after success the app sets `plan='premium'` locally (`AuthNotifier.setUser`) — a server refresh endpoint would make this authoritative.

## Push notifications (deferred, as decided)
The server stores **Expo** push tokens, which Flutter cannot produce. `NotificationService` is a no-op placeholder. To enable: add `firebase_messaging`, add an `fcmToken` field + endpoint on the server, implement `register()`/`unregister()` and call them after sign-in/out when the Profile switch is on.

## Release build (APK / AAB)
1. Create a keystore once: `keytool -genkey -v -keystore ~/readin-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias readin`
2. Create `android/key.properties` (**never commit**):
   ```
   storePassword=…
   keyPassword=…
   keyAlias=readin
   storeFile=/absolute/path/readin-release.jks
   ```
   Without this file the release build falls back to the debug key (fine for testing, not for the Play Store).
3. Build: `flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web id>` (add `--split-per-abi` for smaller APKs) or `flutter build appbundle --release --dart-define=…` for Play.
4. Google sign-in: add the **release keystore SHA-1** (and Play App Signing SHA-1) as another Android OAuth client for `com.micbol.readin`.
5. The design gallery route and the Profile developer tools are **not available in release builds**.
6. Bump `version:` in `pubspec.yaml` for every upload (`1.0.0+2` …).
Smoke-test the release APK on a real device: login, import, read (EPUB + PDF), highlight, audio, sign out.

## Regression script (run top to bottom on a device; tick each)
**Auth** 1 fresh install → onboarding (swipe 5, Skip works, not shown again) · 2 register → "Check your inbox" · 3 login wrong password (exact message) · 4 login alice · 5 restart app → still signed in · 6 forgot password → "Email sent" · 7 Google sign-in · 8 sign out (drawer + profile).
**Shell** 9 four tabs keep state · 10 drawer opens/closes (back button closes it) · 11 toasts/dialogs/sheets.
**Library** 12 empty (alice) / at-limit banner (bob) / premium (carol) · 13 search, sort, grid⇄list · 14 pull to refresh · 15 long-press delete (file removed) · 16 continue-reading banner.
**Discover** 17 popular + infinite scroll · 18 search + category · 19 detail → Add → auto-download → Read Now · 20 duplicate add (409) · 21 free limit dialog (403).
**Import** 22 EPUB + PDF · 23 bad file rejected · 24 offline "read without saving".
**Reader** 25 opens < 2 s · 26 page turn (tap/swipe) · 27 TOC jump · 28 font size/family/theme without losing place · 29 kill + reopen resumes · 30 progress shows in Library · 31 PDF page restore · 32 corrupt file → Re-download.
**Annotations** 33 highlight persists after restart · 34 note + edit · 35 bookmark toggle + list · 36 20-annotation limit dialog · 37 local file toast.
**Profile** 38 stats numbers · 39 free usage bar · 40 default font/theme persist · 41 auto-download off respected.
**Audio** 42 Listen Preview → play/pause/skip/speed · 43 mini player on tabs, open full player from it, close it · 44 finish → mini player closes.
**Upgrade** 45 screen layout, package selection, Start Premium toast, Restore toast.
**Polish** 46 TalkBack reads icon buttons · 47 system font size large → layouts intact · 48 no yellow overflow stripes anywhere (debug) · 49 release APK installs and launches with the RN icon + dark splash.

## Deviations
1. Mini player above the tab bar (not over it) and tab-shell only.
2. "N sentences" label uses the chunk count (consistent with the progress).
3. Premium success flips `plan` locally (no refresh endpoint).
4. Notifications are a no-op until an FCM backend exists.
5. Launcher icon/splash are *configured* (pubspec) — you generate them with the two `dart run` commands (I cannot run them here).

## Not verified
Like all earlier phases: never compiled (no Flutter SDK in my sandbox). New packages: `flutter_tts ^4.0.2`, dev `flutter_launcher_icons ^0.14.1`, `flutter_native_splash ^2.4.1`. TTS quality/voice depends on the device's installed engine.
