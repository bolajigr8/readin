# ReadIn Flutter — Phase 3 (onboarding + auth screens)

Apply on top of Phase 1+2: unzip over the project root (overwrites the Phase-2 sign-in/sign-up/forgot/walkthrough stubs and 2 auth files), then:
```
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
No new packages were added in this phase.

## Google sign-in — how to get what you need (≈10 min)
You **already have the Web client ID**: it is `EXPO_PUBLIC_GOOGLE_CLIENT_ID` in `mobile/.env` of your RN project (it starts with `403175612556-` and ends `.apps.googleusercontent.com`). That is the value for `GOOGLE_SERVER_CLIENT_ID`. To double-check in the console: https://console.cloud.google.com → pick the ReadIn project → **APIs & Services → Credentials → OAuth 2.0 Client IDs** → the row of type **Web application**.

What Flutter needs in addition (the RN app used Expo's proxy, Flutter signs in natively):
1. **Get your debug SHA-1** — in the project folder:
   * Windows: `cd android` then `gradlew.bat signingReport`
   * Mac/Linux: `cd android && ./gradlew signingReport`
   * or: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`
   Copy the **SHA1** line of the `debug` variant.
2. Console → Credentials → **Create credentials → OAuth client ID → Application type: Android**
   * Package name: `com.micbol.readin`
   * SHA-1: the one from step 1 → Create. (No client id needs to be copied from this one; Google matches it automatically by package + SHA-1.)
   * The existing Android client in your .env was made for the Expo build (different SHA-1) — keep it, just add this new one.
3. **OAuth consent screen**: if status is *Testing*, add your Google account under *Test users*.
4. Run with `--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` (VS Code: add it to `args` in `.vscode/launch.json`).
5. Release build later: add one more Android client with the **release keystore** SHA-1 (or the *App signing* SHA-1 from Play Console).
You do **not** need the `https://auth.expo.io/...` redirect URI any more.

Troubleshooting: `ApiException: 10` = SHA-1/package mismatch (step 1–2; changes can take a few minutes) · `12500` = consent-screen/support-email not set · `12501` = user cancelled · `7` = no network. The app shows the RN message ("Google sign-in failed…") and prints the real cause in the debug console as `[Google Auth] …`.

## Parity table
| RN | Flutter | Notes |
|---|---|---|
| `onboarding.tsx` 5 slides, glow rings (3/7/12 %), 5 floating dots, 130/108 icon tiles, accent line, badge pill, 36/44 headline, caption "✦" | `features/onboarding/*` | ✓ copy + alphas copied. Slide 2 uses the **updated import-only copy** |
| Skip (top-right), dot indicator 6→24 px, CTA coloured per slide, "n of 5" | `walkthrough_screen.dart` | ✓ completion writes `@readin/onboarding_complete`, router → sign-in |
| `login.tsx` staggered entrance (420 ms, 80 ms, 24 px) | `StaggeredEntrance` | ≈ easing is `easeInOut` |
| Login validation + 403/401/429/network copy | `utils/validators.dart`, `loginErrorMessage` | ✓ unit-tested. Email is trimmed before the regex check (RN didn't — avoids "valid email" errors from keyboard-added spaces) |
| Google button ("or continue with" divider, "Signing in…", 0.65 opacity) | `_GoogleButton` | ✓ native `google_sign_in` instead of Expo proxy; `avatar` omitted when empty |
| `register.tsx` incl. 409 → email field, network copy "Network error. Check your connection." | `signup_screen.dart` | ✓ "📬 Check your inbox" success, banner uses /10 + /30 alphas |
| `forgot-password.tsx` always shows "Email sent" | `forgot_password_screen.dart` | ✓ even on failure |
| Back link "← Back", "Already have an account? Sign in" | `AuthBackLink`, `AuthLinkRow` | ✓ (sign-in link uses `go`, not push, so the stack doesn't grow) |

## Manual tests (UI_SPEC §4)
1. Fresh install → onboarding: swipe all 5 (colour of dots/button changes per slide); *Skip* on slide 1 jumps to sign-in; relaunch → straight to sign-in (not onboarding).
2. Sign-in: submit empty → both field errors; `x` → "Enter a valid email address"; wrong password → banner "Incorrect email or password."; airplane mode → "Network error. Check your internet connection."; 6 quick wrong attempts → rate-limit message; `alice@readin.test` / `TestPassword123!` → home placeholder.
3. Unverified account (register one) → login shows the server's 403 verification text.
4. Sign-up: each validation message; existing email → red "An account with this email already exists." under Email; success → 📬 screen → *Back to Sign In*.
5. Forgot: invalid → error; any valid email → "Email sent" screen (even offline).
6. Google button: account picker opens → home placeholder; closing the picker shows no error.
7. Compare each screen side-by-side with the RN app (spacing, colours, text sizes).

## Not verified
Same caveat as before: written without a Flutter SDK, never compiled. Paste any `flutter analyze` / runtime output and I'll fix it.
