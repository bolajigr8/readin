# Decisions (ADR-lite). Add new ones at the bottom. Status: ✅ decided · 🟡 recommended, awaiting Michael · ❓ open

## ✅ Decided by Michael
1. **Google Play account type: Individual.** (Implication: closed-testing requirement before production — verify the current numbers in Play Console help; plan to recruit testers from APK users.)
2. **Play billing strategy: support BOTH, via build flavors.** `direct` flavor (APK from our site) uses Paystack. `play` flavor ships first as **consumption-only** (no prices, no purchase buttons/links, no steering to outside payment; users who already have Premium keep access after signing in). Later a **Play Billing** mode can be added to the same flavor (RevenueCat is already on the server) once the Play merchant profile is approved. Server remains the source of truth.
3. **No "remember me". Biometric sign-in instead**, with an on/off switch. Design in `BIOMETRIC_PLAN.md` (app lock; password never stored).
4. **Admin: full control including adding other admins with privileges** → team & roles system in `ADMIN_ROLES_PLAN.md` (owner / admin with permissions / tester).
5. **APK landing page on Vercel** (separate small public site, not the admin) → `LANDING_PAGE_PLAN.md`.
6. **Claude Code (not the chat assistant) implements everything from now on.**
7. applicationId/namespace stays `com.micbol.readin`.

## 🟡 Recommended defaults (proceed with these unless Michael says otherwise)
* **Signing**: generate our own release keystore NOW, before any real user installs; use it for sideloaded APKs; when Play is ready, **import the same key into Play App Signing** (so sideloaded users can upgrade to the Play build without uninstalling — uninstalling would delete locally imported books). Create a separate *upload key* for AAB uploads at that time. Back up the keystore + passwords in two offline places.
* **APK hosting**: GitHub Releases on a *public* repo `readin-releases` (stable URL, CDN, checksums) or Cloudflare R2; **not** Google Drive (scan warnings, quota blocks). The landing page + admin Releases page point at that URL.
* **Distribution artifact**: one **universal** APK for the landing page (simplest for users) plus per-ABI APKs for Michael's testing.
* **Analytics consent**: Analytics **opt-in** (explicit Accept/Decline at first launch, changeable in Profile); Crashlytics on with disclosure + switch. Ads ID disabled (`AD_ID` permission removed). Michael/lawyer to confirm against Nigeria's NDPA.
* **Update mechanism**: server `GET /app/version` + in-app prompt; the app never downloads/installs APKs itself (no `REQUEST_INSTALL_PACKAGES`), it opens the download page.
* **Permissions**: `MANAGE_EXTERNAL_STORAGE` ("on this phone" scan) only in the `direct` flavor; `play` flavor uses the system file picker.
* **Admin 2FA (TOTP)** for owner/admin — later stage, recommended before the audience grows.

## ❓ Open
* Custom domain for the landing page / admin / API (affects Paystack URLs, privacy policy URL, deep links)? Until decided use the Vercel and Render URLs.
* Individual Play account needs Nigeria-supported **merchant (payments) profile** for Play Billing — Michael to check in Play Console once verified.
* ~~Do we keep the legacy `project/mobile` (old Expo app)?~~ Resolved 2026-11-05: `project/mobile` IS the Flutter app; see decisions 8–11.

## ✅ Decided 2026-11-05 (first Claude Code session)
8. **Real layout**: the Flutter app lives in `project/mobile` (pubspec name `readin_flutter`); there is no `flutter/readin_flutter`. All docs updated.
9. **Snapshot commit** of all uncommitted v4–v9 work (incl. removal of the unused linux/macos/web/windows folders) made by Claude Code: `160094b`.
10. **Expo leftovers**: tag `expo-legacy`, then delete `app.json`, `eas.json`, `server/expo-app-details.txt`, the lint-staged `mobile` entry; rewrite `project/README.md` (S0.3).
11. **Husky pre-commit**: keep husky, rewrite the hook — server lint-staged + typecheck; admin `tsc` when admin files are staged; `flutter analyze` when mobile files are staged (S0.3).
12. **iOS kept possible**: `mobile/ios/` restored from `a2ae276` (Flutter template, placeholder bundle id). Android stays first; an iPhone version is a future stage (Swift ports of the native features, Mac + Apple Developer account).
13. **Git workflow (2026-11-06)**: Claude Code works on branches named by type — `feat/…`, `fix/…`, `chore/…`, `docs/…`, `refactor/…`, `test/…` (never `claude/…`, Michael's choice) — merges the latest `origin/main` into the branch and resolves all conflicts + re-runs checks BEFORE pushing, pushes only that branch; Michael opens/merges the pull request on GitHub (merge commit). Pushing to `main`, force-push and remote-branch deletion are blocked in `.claude/settings.json`. Reason: a direct push to `main` was rejected by GitHub (`fatal error in commit_refs_rules`) and Michael wants to review before anything reaches `main` (Render deploys from `main`).
14. **Release signing & backup (S1, 2026-11-06)**: a release build without the release key **fails** (no silent debug-key
    fallback); local opt-out `-P ALLOW_DEBUG_SIGNING=true` only for test builds. Real releases via `mobile/tool/build_release.sh`
    (verifies the certificate). **Phone backup off**: `android:allowBackup="false"` + `data_extraction_rules.xml` excluding all
    data from cloud backup and device-to-device transfer — login tokens are encrypted with a key that never leaves the phone,
    so a restored copy would break sign-in (Michael approved). Versions via `mobile/tool/bump_version.dart`; versionCode +1 every build.
15. **Play first (2026-11-06)**: Michael has a **personal** Play Console account → closed test with ≥12 testers × 14 days is
    required. Order approved: S1.1 key → Play-ready minimum (S8 flavors + AAB, S7.1 account deletion, S3 landing page `project/site`
    with privacy/terms/delete-account, S7.4 listing + forms) → closed test → remaining stages (S2, S4, S5, S6, S9) shipped as
    updates to testers → `/play-audit` → production. Michael wants **every feature + the landing page ready before the public launch**.
    Testers only need a Google account to join the Play test; Google sign-in inside ReadIn is NOT required (stays off).
16. **Payments by distribution (2026-11-06, Michael)**: Play version = **Google Play Billing** (main system; most users come
    from the Play link) with **two plans: monthly and yearly auto-renewing subscriptions**; connected through **RevenueCat**
    (free < ~$2.5k/month; server code exists) → server `premiumUntil`. APK/website = Paystack (kept; firewall fix "start payment
    from the phone" done before launch — paused now). Premium belongs to the ACCOUNT, whatever paid it. The app tells the server
    its distribution (`X-App-Distribution`); the server refuses Paystack checkout from the Play version.
17. **S8 approved (2026-11-06)**: flavors `direct` (APK: Paystack, whole-phone scan with MANAGE_EXTERNAL_STORAGE) and `play`
    (AAB: no Paystack, no all-files permission — "Choose a folder"/share/open-with stay). Same applicationId. Whole-phone scan in
    Play may be requested later via the Permissions Declaration (document management) once the app is approved — not for launch.
18. **Launch details (2026-11-06, Michael)**: support e-mail **micboltech@gmail.com** (store listing, privacy, terms, delete-account).
    Domain: **readin.micbol.org** (subdomain of Michael's micbol.org — free; optional api./admin. subdomains; Resend sender on it).
    Michael wants prices + free trial set in the ADMIN dashboard: Paystack plans already are; for Google Play prices must exist in
    Play Console — proposed (a) Play Console at launch with admin showing/toggling, (b) admin edits Google prices via the Play
    Developer API (service account) later. **Michael chose (a) at launch.** Landing page on **Cloudflare Pages** (free, commercial
    use allowed; Vercel Hobby is non-commercial). micbol.org DNS is managed at **Spaceship**.
19. **Website = Next.js (2026-11-06, Michael)**: `project/site` rebuilt as a Next.js 16 app like the admin (static export,
    Cloudflare Pages), with `motion` animations, both light and dark mode + a theme switch. New packages (site only): next
    16.4.3, react/react-dom 19.3.0, motion, geist, lucide-react; dev: tailwindcss 4, @tailwindcss/turbopack, typescript,
    eslint + eslint-config-next 16.4.3. Next 16.4.0 is flagged with a security vulnerability → the site uses 16.4.3; the
    ADMIN still uses 16.4.0 → upgrade it on its own branch (ask Michael).
