# Signing, APK distribution, Google Play & Android developer verification

> Policy facts below are from the previous assistant's knowledge (to mid-2026) and WILL drift. Before acting on any
> "policy" line, open the linked official page and confirm. Mark each item you verified with the date.

## 1. Strategy in one paragraph
Phase 1 sideload APK (landing page) → Phase 2 analytics/crash reporting → Phase 3 Play release. The same package name
and the **same signing certificate** must be used throughout so installed users can update in place. Local-first
imported books live on the phone, so an uninstall (forced by a certificate change) would destroy user data — treat
signing-key continuity as the top technical risk.

## 2. Signing
### 2.1 Create the key (Michael, once — never commit it)
```bash
# Windows Git Bash; keytool ships with Android Studio:  "C:/Program Files/Android/Android Studio/jbr/bin/keytool"
mkdir -p ~/readin-keys
keytool -genkeypair -v -keystore ~/readin-keys/readin-release.jks -alias readin \
  -keyalg RSA -keysize 2048 -validity 10000
# fingerprints to record in this file (NOT the passwords):
keytool -list -v -keystore ~/readin-keys/readin-release.jks -alias readin
```
Back up the `.jks` and both passwords in two separate offline places. 10 000 days ≈ 27 years (Play requires validity well beyond 2033).

### 2.2 Wire it (Claude Code, S1)
* `project/mobile/android/key.properties` (git-ignored by `project/mobile/android/.gitignore`):
  `storePassword=… keyPassword=… keyAlias=readin storeFile=C:/Users/MICBOL/readin-keys/readin-release.jks`
* `android/app/build.gradle.kts` already reads `key.properties` but **silently falls back to the debug key** → change so a *release* build **fails** without the key (allow an explicit opt-out property for local testing only). **Any APK given to real users must be signed with the release key.** Debug-key APKs already installed on test phones cannot be updated by release-signed APKs (uninstall once).
* Record here after S1: `Release certificate SHA-256: ____`  `SHA-1: ____`  `First release date: ____`.

### 2.3 Play App Signing (future, no surprises)
* Plan: when creating the Play app choose **“Use existing key / upload your own app signing key”** and import `readin-release.jks` via Google's **PEPK** tool (download link and exact command are in Play Console → Setup → App signing; roughly `java -jar pepk.jar --keystore=… --alias=readin --output=output.zip --include-cert --rsa-aes-encryption --encryption-key-path=<Google's public key>`). Result: the Play-delivered app has the **same certificate** as the APK users already have → in-place updates from sideload to Play.
* Create a **separate upload key** at that time for signing AABs you upload.
* Firebase/Google sign-in/Play integrity use the **certificate SHA fingerprints** — add the release SHA-1/256 to Firebase now and add Play's app-signing SHA when it exists.
* If we ever must use a Google-generated app signing key instead, sideloaded users will have to uninstall/reinstall to move to the Play build (data loss for local-only imports) — avoid.

## 3. Versioning
`pubspec.yaml version: 1.0.0+1` → versionName `1.0.0`, versionCode `1`. versionCode must always increase (Play and Android require it). Server keeps `minSupportedVersionCode`.

## 4. APK hosting
* **Not Google Drive** for the public link (virus-scan interstitials, quota “too many downloads” blocks, unstable direct links).
* Recommended: **GitHub Releases** on a public repo `readin-releases` (free, CDN, stable URL, checksum in notes) or Cloudflare R2 (no egress fees). The landing page and the admin *Releases* page store only the URL + SHA-256.
* Serve over HTTPS only; show SHA-256 so users/support can verify. Consider a short custom domain later.
* Expect friction: Play Protect “unrecognized app” prompt, “Install unknown apps” permission for the browser, Samsung **Auto Blocker** (blocks sideloading until turned off). The landing page must explain each with screenshots.

## 5. Android developer verification (sideloaded apps) — https://developer.android.com/developer-verification
* Announced direction: apps installed on certified Android devices will need to be registered by a verified developer; phased rollout (some countries first in 2026, broader after). There is an “advanced flow” for experienced users and a lighter registration type for hobbyists/students.
* Impact: **identity documents are needed even for sideloaded distribution.** Re-check the page for Nigeria's date, the registration steps, whether the package name + signing certificate fingerprint must be registered, and fees. Put the verified facts + dates here: `Nigeria enforcement: ____ (checked ____)`.

## 6. Google Play: checklist
| Area | Requirement | State / action |
|---|---|---|
| Account | Individual identity verification; payments profile if selling | Michael — MANUAL_TASKS |
| Testing | Individual accounts: closed test with a minimum number of testers for a minimum number of days before production access (confirm numbers) | recruit from APK users; collect their Google-account e-mails with consent |
| App content | Privacy policy URL (public, not PDF-only), Data safety form, ads declaration (none), content rating (IARC), target audience, news/health/financial declarations (n/a) | S7.4 drafts |
| Account deletion | Apps with account creation must offer deletion **in-app AND via a web URL** | S7.1 |
| Permissions | `MANAGE_EXTERNAL_STORAGE` is restricted (only approved for core functions like file managers/backup) → **`direct` flavor only**; `READ_EXTERNAL_STORAGE`≤32 OK; `POST_NOTIFICATIONS` OK; exact alarms: `USE_EXACT_ALARM` is for alarm/calendar apps, `SCHEDULE_EXACT_ALARM` is user-grantable and needs Play declaration — check what `HabitAlarms.kt` uses and prefer inexact/WorkManager-style where acceptable | S7.2 |
| Foreground service | `mediaPlayback` type declared in manifest ✅; Play Console requires a foreground-service declaration + demo video | MANUAL |
| Target API | New apps/updates must target a recent API level (rises every year ~Aug 31) | check `flutter.targetSdkVersion`/`compileSdk` (build has a compileSdk 36 override for plugins) |
| Build | **AAB** (`flutter build appbundle`), 64-bit included by Flutter | S8.2 |
| Network | HTTPS only (cleartext limited to loopback for the reader) ✅ | keep |
| Data safety facts | Collected: e-mail, display name, books/notes/progress (account content), app interactions + crash logs (Firebase, if consent), purchase history (Paystack ref/amount). Shared with: Firebase/Google, Cloudinary, MongoDB Atlas, Render, Resend, Paystack (processors). Encrypted in transit; deletion available. | S7.4 |

## 7. Payments & Play policy (decision DECISIONS #2)
* Digital subscriptions sold **inside** an app distributed on Play must normally use **Google Play Billing**. Exceptions/programmes (user-choice billing, external-offers) are region-specific — **do not assume Nigeria is covered; do not add external payment links in the Play build.**
* `play` flavor, phase A = **consumption-only**: no prices, no upgrade buttons, no text/links that point to buying elsewhere; signed-in users with Premium see “Premium active until …”. Phase B = Play Billing via RevenueCat → server `premiumUntil`.
* `direct` flavor keeps Paystack. Server stays authoritative; both flavors read the same entitlements.
* Implement the split with `BillingPolicy` + `kDistribution` (S8.1). Also hide Paystack-specific copy (e-mails, landing page) from the Play listing.

## 8. Release process (target state)
1. `/verify-all` → 2. bump version → 3. `tool/build_release.sh` (verify signature + print SHA-256) → 4. upload APK to the host → 5. add the release in admin → 6. test update-over-install on a real phone → 7. announce. Keep a table of releases below.

| version | code | date | cert SHA-256 | APK SHA-256 | notes |
|---|---|---|---|---|---|
