# Fixes after the first `flutter analyze` / `flutter test` run (2026-10-05)

Reported by you: 1 analyzer **error**, 1 warning, 30 infos; 7 failing test files/tests (dio 5.11.1, Flutter/Dart 3.12).

| # | Report | Cause | Fix |
|---|---|---|---|
| 1 | `error_interceptor.dart:21` switch not exhaustive (`DioExceptionType.transformTimeout`) | Dio ≥ 5.10 added a new enum value. **This one error also made 4 test files fail to compile** (api_client, annotations, discover, import) | handled `transformTimeout` → `RequestTimeoutException` |
| 2 | `annotations_test.dart:165` `Null` not assignable to `Object` | test helper signature | `_ok(Object? data, …)` |
| 3 | `reader_server_test` "HttpServer is not bound to a socket" | test read `pageUrl` (needs the port) **after** `close()` | read the URL before closing |
| 4 | `reader_test` ProgressSync dispose: expected 1 send, got 2 | `flush()` still ran after `dispose()` | `flush()` returns when disposed; removed the unused `_dirty` field (analyzer warning) |
| 5 | `widget_test` `titleInitials('Pride and Prejudice')` expected `PP`, got `PA` | **my test was wrong**: RN `getTitleInitials` = first letters of the first TWO words (Pride, and → `PA`); the code matches RN | test corrected (+ an extra case) |
| 6 | infos: `unnecessary_underscores` ×9 | `(_, __)` style | `(_, _)` / `(_, _, _)` |
| 7 | infos: `prefer_const_constructors` ×3, `use_super_parameters`, `use_null_aware_elements` | style | fixed (`const AuthState(...)`, `super.statusCode`, `'note': ?note`) |
| 8 | infos: `prefer_initializing_formals` ×15 | `_x = x` initialisers keep **public named parameters** with private fields | lint disabled in `analysis_options.yaml` (intentional) |

Good news from your output: **no other compile errors** — the reader, drawer, WebView, pdfrx, file_picker, flutter_tts and go_router code all analysed clean, and 71 tests already passed. The 4 test files that could not compile (see #1) are now being compiled for the first time, so a few more test failures may appear — paste them and I'll fix them.

---
# Fix 2 — build failure on device (`flutter run`)
`ionicons-0.2.2/lib/ionicons.dart: Error: The class 'IconData' can't be extended outside of its library because it's a final class.`
The pub package `ionicons` is abandoned and no longer compiles with current Flutter (`IconData` became `final`). (`flutter analyze` did not flag it because it only analyses your own `lib/`.)

**What changed**
* Removed the `ionicons` dependency (and the unused `share_plus`, which only produced a Kotlin-plugin warning).
* New `lib/constants/ionicons.dart`: a local `Ionicons` class with the **same names** (`Ionicons.book_outline`, …) backed by Flutter's Material icons → the app builds with **no extra step**. All 31 files now import `package:readin_flutter/constants/ionicons.dart`.
* **Exact RN icons (recommended, 1 minute):** the Material icons are only look-alikes. To get the identical Ionicons font your RN app uses, run once from the Flutter project root:
  ```
  dart run tool/gen_ionicons.dart <path-to-your-RN-project>      # e.g. ../../react-native-app/mobile
  flutter pub get
  flutter run
  ```
  The tool reads `node_modules/@expo/vector-icons/**/Ionicons.json` + `Ionicons.ttf` (run `npm install` in the RN project if `node_modules` is missing), regenerates `lib/constants/ionicons.dart` with **all** Ionicons glyphs, copies the font to `assets/fonts/Ionicons.ttf` and registers it in `pubspec.yaml`. If it cannot find the files: `dart run tool/gen_ionicons.dart --json <path>/Ionicons.json --ttf <path>/Ionicons.ttf`.
* The remaining Gradle message "plugins that apply Kotlin Gradle Plugin: flutter_tts, share_plus" is only a **future-deprecation warning**, not an error (share_plus is gone now; flutter_tts will need an update from its author eventually).
