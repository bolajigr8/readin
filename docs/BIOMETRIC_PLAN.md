# Biometric sign-in (replaces “remember me”) — design

Michael asked for **biometric sign-in with an on/off switch** and explicitly *no* “remember me”.
Because the app never stores the password, “biometric sign-in” = **a fingerprint/face unlock of the existing session** (a quick unlock), not a password replacement:

* The session (access/refresh tokens in `flutter_secure_storage`) already keeps users signed in. Biometric ON = the app shows a lock screen on **cold start** and after the app has been in the background longer than the chosen delay (Immediately / 1 min [default] / 5 min), until the biometric succeeds.
* “Use password instead” (or 3 failed attempts / biometrics unavailable) → sign out (tokens cleared, local library kept) → normal sign-in screen.
* Switch lives in **Profile → Security → “Unlock with fingerprint / face”**. Turning it ON asks for a successful biometric scan first; OFF requires one too. Stored flag in prefs (`@readin/biometric_enabled`, `@readin/biometric_delay`). Cleared on sign-out (new user must opt in).
* A device with no enrolled biometrics: show the switch disabled with a plain explanation (“Add a fingerprint in your phone settings first”).
* Optional later: a biometric button on the sign-in screen is impossible without storing credentials — do not store passwords; passkeys/WebAuthn would be the future route.

## Implementation notes
* Package `local_auth` (check latest). Android: **`MainActivity` must extend `FlutterFragmentActivity`** (currently `FlutterActivity` + custom share-intent code — keep that code working), manifest `<uses-permission android:name="android.permission.USE_BIOMETRIC"/>`, and the launch theme must derive from `Theme.AppCompat…` (the plugin docs/known error “FragmentActivity/AppCompat required”) — adjust `res/values*/styles.xml` carefully and re-check splash/launch background, night variants and Android 12+ splash.
* Wrap the plugin in `BiometricService` (interface: `isAvailable()`, `authenticate(reason)`) + `FakeBiometricService` for tests. Use `authenticate(biometricOnly: true)` with `persistAcrossBackgrounding: true` behaviours as supported by the installed plugin version.
* `AppLockController` (Riverpod): states `unlocked | locked | disabled`; observes lifecycle (record `pausedAt`); lock overlay is a top-level widget in `app.dart` above the router so deep links/shared files can't bypass it; the incoming-file queue waits until unlocked. Read-aloud audio may continue while locked (UI only locks).
* Analytics: `login` with `method=biometric` is NOT a login (no server call) — log `feature_used(feature_name=biometric_unlock)` only.
* Tests: lock timing, enable/disable flows, failure counts, unavailable hardware, lifecycle; manual: enrolled/unenrolled, biometric change, screen rotation during prompt, share-intent while locked.
