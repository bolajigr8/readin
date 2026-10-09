# ReadIn Flutter — Phase 1 + 2 delivery

## 1. Install (copy over your project `readin_flutter/`)
1. **Delete** `android/app/src/main/kotlin/com/example/` (old MainActivity). The new one is in `com/micbol/readin/`.
2. Unzip this archive over the project root (it replaces `lib/main.dart`, `pubspec.yaml`, `analysis_options.yaml`, `test/widget_test.dart`, the Android gradle/manifest, and adds everything else).
3. If Android Studio complains about the package change: `flutter clean`.
4. Run:
```
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=https://readin-ehzw.onrender.com/api/v1
```
(`API_BASE_URL` already defaults to that URL, taken from your RN `.env`; the define is only needed to change it.)
Google sign-in additionally needs: `--dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB client id>`.

## 2. Google sign-in setup
* Google Cloud Console → Credentials → **Android** OAuth client: package `com.micbol.readin` + your debug SHA-1
  (`cd android && ./gradlew signingReport`).
* Also create/use a **Web** client; pass its id as `GOOGLE_SERVER_CLIENT_ID`.
* Server note: `/auth/google` rejects `avatar: ""`, so the app omits the key when Google has no photo.

## 3. What changed vs the pack's prompts (decisions)
| Prompt said | I did | Why |
|---|---|---|
| `flutter create --project-name readin`, imports `package:readin/` | Kept your existing project name `readin_flutter` | You already created it |
| Bundle Inter TTFs | Inter via `google_fonts` (downloads once, cached) | No font files / no network here. Swap = one line in `app_typography.dart` |
| Refresh queue | Single-flight refresh in `TokenService` | Simpler, provably one refresh call |
| Refresh failure → logout | Logout only if refresh is *rejected* (4xx / missing token). Offline during refresh keeps the session | Avoids logging users out on bad signal |
| Toast on every API error | Only cross-cutting ones (session expired) go through `globalErrorProvider` | Screens show inline errors like RN |

## 4. Parity table — Phase 1 (tokens / typography / shared widgets)
| RN element | Flutter | Match |
|---|---|---|
| `THEME.colors.*`, reader palettes, highlights, 8 cover colours | `constants/app_colors.dart` | ✓ values copied 1:1 |
| `color + '25'` hex-alpha | `AppColors.alpha(c, 0x25)` | ✓ |
| spacing / radius | `app_spacing.dart`, `app_dimensions.dart` | ✓ |
| Inter 400/500/600/700 named styles | `AppTypography` (`h1`, `title22`… + `label()`) | ✓ (≈ font source: google_fonts) |
| `ui/Button` 4 variants × 3 sizes, loading, opacity .5 | `AppButton` | ✓ |
| `ui/Input` (label, 56px, icon, eye, error) | `AppTextField` | ✓ |
| `EmptyState` | `EmptyState` | ✓ |
| `LoadingSpinner` | `AppLoader` | ✓ |
| Toast (top, 3 max, 3500 ms, slide −80 + fade 200) | `AppToast` | ≈ slide uses easeOutCubic, not RN spring |
| `getCoverColor` / `getTitleInitials` / format helpers | `utils/book_visuals.dart`, `formatters.dart` | ✓ unit-tested |
| Dark only + CustomColors extension | `AppTheme` / `CustomColors` (light == dark) | ✓ |

## 5. Phase 2 — files
`core/api/*` (client, result, endpoints, 3 interceptors) · `core/errors/app_exception.dart` · `core/services/{storage,token,routes,router,global_error*,navigator_keys}.dart` · `features/auth/{data,providers,screens,utils}` · placeholders · `app/app.dart`.

Temporary (replaced in Phase 3/4/5): `SignInScreen` is a *functional* minimal version; onboarding, sign-up, forgot, home and all other routes are placeholders.

## 6. Manual tests
**Phase 1**
1. App boots straight to *Design gallery* only if you navigate there (Phase 2 routes to splash → onboarding). Open it from the home placeholder ("Design gallery (dev)") after login, or temporarily set `initialLocation` to `AppRoutes.gallery`.
2. Compare swatch hex values, type sizes, buttons, inputs, empty state and the 4 toasts against the RN app.

**Phase 2**
1. First launch → splash → onboarding placeholder → *Get Started* → Sign in.
2. Wrong password → "Incorrect email or password."
3. `alice@readin.test` / `TestPassword123!` (after `npm run seed`) → "Signed in ✓" with name/email/plan.
4. Kill the app, reopen → lands on home directly (no login).
5. Sign Out → back to sign-in; reopen → still signed out.
6. Offline login → "Network error. Check your internet connection."
7. 401 refresh (optional): in Render set a 10 s access-token lifetime or wait 15 min, tap any API screen → no logout.
8. `flutter test` → all tests in `test/core/api_client_test.dart` pass (401→refresh→retry once; two simultaneous 401s → one refresh; refresh rejected → logout; `{success:false}` → `Failure(ServerException)`).

## 7. Not verified
This was written without a Dart/Flutter SDK available, so **nothing has been compiled or run**. I checked imports resolve and brackets balance. Expect possibly a few analyzer errors/infos on the first `flutter analyze` — paste them back and I fix them.
