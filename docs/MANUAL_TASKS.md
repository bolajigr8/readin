# What only Michael can do (Claude Code cannot)

## Start today (they take the longest)
1. **Google Play identity verification (Individual)** — gather: a valid government ID (check Play Console's accepted list), proof of address in the same name (bank statement/utility bill, recent), phone + e-mail access, a payment profile using the exact same name. Keep clear photos/scans ready. Start the verification in Play Console as soon as the account allows it.
2. **Android developer verification (for sideloaded APKs)** — read https://developer.android.com/developer-verification and register the package `com.micbol.readin` + the release key fingerprint when the console opens for your region (enforcement is being phased in; the rules may require registering even without a Play account). Re-read the page before each release — it changes.
3. **Create and back up the release keystore** (after Claude Code explains the command in S1): two offline copies (e.g. encrypted USB + password manager), store the passwords separately. Losing it = no more updates for installed users.

## Accounts / consoles
* **Firebase**: create project "ReadIn", add Android app `com.micbol.readin` (add SHA-1 and SHA-256 of the release key, and of the debug key for testing), download `google-services.json` into `project/mobile/android/app/` (never commit if the plan says so), turn on Analytics + Crashlytics; DebugView for testing (`adb shell setprop debug.firebase.analytics.app com.micbol.readin`).
* **GitHub**: create public repo `readin-releases` (APK hosting) — or a Cloudflare R2 bucket.
* **Vercel**: second project for the landing page (Root Directory `site`); keep the admin project separate. (Reminder: Vercel's free Hobby plan is for non-commercial use — check their terms; Pro or Cloudflare Pages are the compliant options for a business.)
* **Render**: add env vars as each stage says (never paste secrets in chat or commits): `RELEASE_HOST_ALLOWLIST`, `GA4_*` (optional), keep `PAYSTACK_SECRET_KEY`, `APP_URL`, `ADMIN_EMAILS`.
* **Paystack**: after deploying server v7 press *Billing → Test connection*; later switch to live keys (business verification) and set the Live webhook URL.
* **Resend**: verify your sending domain so e-mails are delivered (`EMAIL_FROM` must use it).
* **cron-job.org**: re-enable the health job (URL `/api/v1/health`, GET, 30 s timeout, every 10 min 06:00–22:59).

## Devices
Keep at least: the Samsung A175F + one older Android (8–10 if you can borrow) + one recent. Test update-over-install, biometrics (needs an enrolled fingerprint/face), notifications, read-aloud, payments.

## Play Console (after verification)
Create app (default language, free app), complete **App content** (privacy policy URL from the landing page, data-safety form, ads: none, target audience, content rating questionnaire, account-deletion URL, foreground-service declaration for media playback, exact-alarm declaration if used), set up **closed testing** (Individual accounts must run a closed test with a minimum number of testers for a minimum number of days before production — confirm the current numbers), merchant profile only when we implement Play Billing, upload the **AAB**, enrol in **Play App Signing** using the existing key (Claude Code will give the PEPK steps).

## Legal
Have the privacy policy and terms (drafted by Claude Code) reviewed by someone qualified; confirm Nigeria data-protection (NDPA) obligations (consent, data-protection officer/registration thresholds, cross-border transfer notes for Firebase/Cloudinary/Resend/MongoDB Atlas/Render).
