# Signing, APK distribution, Google Play & Android developer verification

> Policy facts below are from the previous assistant's knowledge (to mid-2026) and WILL drift. Before acting on any
> "policy" line, open the linked official page and confirm. Mark each item you verified with the date.

## 1. Strategy in one paragraph
Phase 1 sideload APK (landing page) → Phase 2 analytics/crash reporting → Phase 3 Play release. The same package name
and the **same signing certificate** must be used throughout so installed users can update in place. Local-first
imported books live on the phone, so an uninstall (forced by a certificate change) would destroy user data — treat
signing-key continuity as the top technical risk.

## 2. Signing
### 2.1 Create the key (Michael, once — never commit it, never paste the passwords into a chat)
```bash
# Git Bash. keytool ships with Android Studio:
KT="/c/Program Files/Android/Android Studio/jbr/bin/keytool.exe"
mkdir -p ~/readin-keys
"$KT" -genkeypair -v -keystore ~/readin-keys/readin-release.jks -alias readin   -keyalg RSA -keysize 2048 -validity 10000
#   It asks for a password (twice) and your name / organisation / city / country code (NG).
#   The key password is the SAME as the store password (modern PKCS12 keystores) — keytool won't ask twice.
# Fingerprints to record below (NOT the passwords):
"$KT" -list -v -keystore ~/readin-keys/readin-release.jks -alias readin | grep -E "SHA1:|SHA256:"
```
Back up the `.jks` and the password in **two separate offline places** (e.g. a USB stick kept at home + a password
manager; never only on this PC). 10 000 days ≈ 27 years (Play requires validity well beyond 2033).
**Losing the key or the password = no more updates for everyone who installed ReadIn.**

### 2.2 Wire it (done in S1, 2026-11-06)
* Copy `project/mobile/android/key.properties.example` → `project/mobile/android/key.properties` (git-ignored) and fill in:
  `storeFile=C:/Users/MICBOL/readin-keys/readin-release.jks`, `storePassword=…`, `keyAlias=readin`, `keyPassword=…` (same password).
* `android/app/build.gradle.kts`: a **release build fails** if `key.properties` is missing/incomplete or the `.jks` is not found
  (message explains why). Local test only: `flutter build apk --flavor direct --release -P ALLOW_DEBUG_SIGNING=true` (or env
  `READIN_ALLOW_DEBUG_SIGNING=true`) — such an APK must never reach users. `tool/verify.sh --apk` uses that opt-out only when no key exists.
* **Real releases:** `cd project/mobile && bash tool/build_release.sh` → runs the app checks, builds universal + per-ABI APKs,
  `apksigner verify --print-certs` each (refuses the debug key / mixed certificates), copies them to
  `build/release/<version>/readin-<version>-<abi>.apk` with a notes file (certificate SHA-256, sizes, file SHA-256).
* Debug-key APKs already installed on test phones cannot be updated by release-signed APKs → **uninstall once** (local-only books on that phone are lost).
* **Google Play bundle (S8):** `cd project/mobile && bash tool/build_play.sh` → `build/release/<version>/readin-<version>-play.aab`.
  Signed with the **upload key** if `key.properties` has `uploadStoreFile`, `uploadStorePassword`, `uploadKeyAlias`, `uploadKeyPassword`
  (create `~/readin-keys/readin-upload.jks` with the §2.1 command, alias `upload`), otherwise with the release key. The script refuses
  the debug key and fails if the Play manifest contains `MANAGE_EXTERNAL_STORAGE`.
* **ReadIn release key (created by Michael 2026-11-06, alias `readin`, RSA 2048, 10 000 days):**
  * SHA-256: `15:B3:69:E4:C5:89:10:FB:A4:8A:25:F4:E7:BE:6D:B9:49:70:39:E9:07:27:DB:7E:56:B4:30:29:C5:09:08:10`
    (apksigner form: `15b369e4c58910fba48a25f4e7be6db9497039e90727db7e56b43029c5090810`)
  * SHA-1: `D6:97:EC:77:47:09:06:EE:E1:78:09:43:A2:11:3B:DD:6C:36:DF:8F`
  * Every APK/AAB we ship must show exactly this SHA-256 (`tool/build_release.sh` prints it). Use these for Firebase (S6) and
    Play App Signing ("use my own key"). First release date: ____

### 2.3 Play App Signing (future, no surprises)
* Plan: when creating the Play app choose **“Use existing key / upload your own app signing key”** and import `readin-release.jks` via Google's **PEPK** tool (download link and exact command are in Play Console → Setup → App signing; roughly `java -jar pepk.jar --keystore=… --alias=readin --output=output.zip --include-cert --rsa-aes-encryption --encryption-key-path=<Google's public key>`). Result: the Play-delivered app has the **same certificate** as the APK users already have → in-place updates from sideload to Play.
* Create a **separate upload key** at that time for signing AABs you upload.
* Firebase/Google sign-in/Play integrity use the **certificate SHA fingerprints** — add the release SHA-1/256 to Firebase now and add Play's app-signing SHA when it exists.
* If we ever must use a Google-generated app signing key instead, sideloaded users will have to uninstall/reinstall to move to the Play build (data loss for local-only imports) — avoid.

## 3. Versioning
`pubspec.yaml version: 1.0.0+1` → versionName `1.0.0`, versionCode `1`. versionCode must always increase (Play and Android
require it; a phone refuses an "update" whose versionCode is not higher). Server keeps `minSupportedVersionCode` (S2).
Use the helper (from `project/mobile`): `dart run tool/bump_version.dart patch|minor|major|build` (`show`, `--dry-run`).
`patch` = fixes (1.0.0→1.0.1), `minor` = new features (→1.1.0), `major` = big change (→2.0.0), `build` = same version, new build.
Every one of them raises versionCode by exactly 1. Bump on the release branch before `tool/build_release.sh`; never reuse a number.

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
| Account deletion | Apps with account creation must offer deletion **in-app AND via a web URL** | ✅ S7.1 done: app Profile → Delete account; web **https://readin-ehzw.onrender.com/delete-account** (later readin.micbol.org/delete-account) |
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

## 7b. Verified Google Play facts (researched 2026-11-06 — re-check before submitting)
Michael has a **Google Play Console account** (2026-11-06) → Play publishing is now the main goal; the APK stays as a second channel.
| Topic | Fact (source) | ReadIn status / action |
|---|---|---|
| Closed test (personal accounts created after 13 Nov 2023) | ≥ **12 testers opted in for the last 14 days continuously**, and they should really use the app; then apply for production (review usually ≤ 7 days). Organisation accounts (D-U-N-S) are exempt. | Critical path: start the closed test as early as possible. Testers need Google accounts. |
| Target API | New apps + updates must target **API 36 (Android 16)** since 31 Aug 2026 (Play Console Help 11926878). | ✅ targetSdk 36, minSdk 24 (checked in the merged manifest). |
| 16 KB memory pages | Required for apps targeting Android 15+. | ✅ all arm64 `.so` files are 16 KB-aligned (zipalign -P 16 + ELF check, 2026-11-06). |
| Format | AAB upload, Play App Signing. | S8.2. **At the first upload choose "use my own key" (import `readin-release.jks` with PEPK)** so APK users can move to Play without uninstalling. Needs S1.1 first. |
| Payments | Google Play Billing **is available in Nigeria** (merchant registration supported, users pay in naira) → digital Premium sold inside the Play app **must** use Play Billing. Alternative billing / external links programmes cover US, UK, EEA (+ India, South Korea) — **not Nigeria** (June 2026 blog). | Keep DECISIONS #2: Play build = no prices, no Paystack, no links to buy elsewhere (phase A); Play Billing later (S8.3). Paystack stays in the APK. Merchant payouts in USD to a domiciliary account. |
| `MANAGE_EXTERNAL_STORAGE` | Only for approved core uses (e.g. document management) with a declaration; file picking / reading own library must use the Storage Access Framework. | Remove from the Play build (S8 flavors). The system file picker + share/open-with already cover imports. |
| Foreground service | `mediaPlayback` type ✅ in manifest; Play Console → App content → Foreground service: choose Media playback + a short demo video (app reading aloud while minimised). | Michael records the video. |
| Account deletion | Apps with sign-up must offer deletion **in the app AND on a web page** that works without the app; link in the Data safety form; say what is kept and why. | S7.1 (server + app) + site `/delete-account` (S3). |
| Privacy policy | Required for every app; public web page (not a PDF), must match the Data safety answers. | Site `/privacy` (S3). |
| Data safety form | Must be accurate (misrepresentation = removal). Covers e-mail, name, books/notes/progress, crash/analytics (if added), purchase history; processors; encryption in transit; deletion. | S7.4 draft answers; update when Firebase (S6) is added. |
| App access for reviewers | Give a working login (no 2-step, no expiry) + instructions; the reviewer must reach every feature incl. Premium screens. | Create a verified reviewer account; give it Premium via admin gift. |
| Other App content forms | Ads (none), content rating (IARC questionnaire), target audience (choose 13+ or 18+ — under-13 brings the Families policy), news/health/financial/government (no). | S7.4 answers. |
| Developer verification (sideloading) | Play-verified developers: eligible Play apps are **registered automatically**; Play Console can also register apps distributed outside Play. Enforcement: Brazil, Indonesia, Singapore, Thailand from 30 Sep 2026; **global in 2027**. Unregistered apps still installable via ADB / "advanced flow". | Nigeria not enforced yet; once the app is on Play with the same key, check Play Console shows it registered (covers the APK too). |
| User monitoring | No Google Tag Manager needed (GTM for apps only forwards Firebase events). **Play Console gives for free**: installs/uninstalls, countries, devices, ratings/reviews, **Android vitals** (crashes, ANRs, slow start), acquisition reports. Detailed in-app behaviour = Firebase Analytics + Crashlytics (S6, with consent). | Use Play Console now; S6 later. |
Sources: Play Console Help (target API 11926878, account deletion 13327111, Data safety 10787469, All-files access 10467955,
supported locations 9306917, payments 10281818), Android Developers Blog (2026-03 developer verification, 2026-06 billing choice).

## 8. Release process (target state)
1. `/verify-all` → 2. bump version → 3. `tool/build_release.sh` (verify signature + print SHA-256) → 4. upload APK to the host → 5. add the release in admin → 6. test update-over-install on a real phone → 7. announce. Keep a table of releases below.

| version | code | date | cert SHA-256 | APK SHA-256 | notes |
|---|---|---|---|---|---|
