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
* Do we keep the legacy `project/mobile` (old Expo app) in the repo? Recommend archiving it in a branch/tag and deleting from `main` (it triggers the husky `mobile` lint on every commit).
