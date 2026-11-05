# APK landing page (`project/site`, deployed on Vercel as a SEPARATE project from the admin)

## Goals
A fast public page where people download the latest ReadIn APK safely, understand how to install it, and find privacy/terms/account-deletion links (these URLs are also needed for Google Play later).

## Stack
Same toolchain as the admin (Next.js 16, TypeScript, Tailwind 4, pnpm) so there is one way of working — **read `node_modules/next/dist/docs/` first (Next 16 differs from older versions)**. Mostly static; one server fetch with ISR (`revalidate: 60`). No cookies, no trackers on this site initially (privacy-friendly). Brand: orange primary (`#F97316`-family, check `AppColors.primary500` in the app), dark/light theme via prefers-color-scheme.

## Data
`GET {API}/app/version?platform=android` (S2.1; public). Fields: latestVersion, latestVersionCode, releasedAt, sizeBytes, sha256, downloadUrl, releaseNotes[], minSupported. `NEXT_PUBLIC_API_URL` env (public data, so `NEXT_PUBLIC_` is fine here). If the API is asleep/unreachable, show the last good data from build time (`public/latest.fallback.json` generated at build) and never a blank page.

## Sections
1. Hero: logo, tagline, **Download for Android** button (+ version, size, date) and a QR code to the page.
2. “Install in 3 steps” with screenshots: download → open file → allow “Install unknown apps” for your browser → Install; **Play Protect** “unrecognized app” → *More details → Install anyway*; **Samsung Auto Blocker** off; how to update later (install over the old one — your books stay).
3. Verify your download: SHA-256 + how to check it; “signed by ReadIn” certificate fingerprint (from PLAY_AND_DISTRIBUTION).
4. What's new (latest release notes) + older releases list.
5. Features overview (read EPUB/PDF/docs, import from phone, offline fonts, habits, read-aloud, notes).
6. FAQ: is it safe, why not on Play yet, data/privacy, Android version support, uninstall, support e-mail.
7. Footer: Privacy · Terms · Delete my account · Contact.
`/download` route → 302 to the latest `downloadUrl` (stable link for QR/WhatsApp sharing).
`/privacy`, `/terms`, `/delete-account` (explains in-app deletion + request form/e-mail flow tied to S7.1). Draft text written by Claude Code, marked for legal review. `robots.txt`, sitemap, Open Graph image, `lang="en"`, accessibility (contrast, alt text), mobile-first (most visitors are on phones).

## Deploy
Vercel → New Project → same repo → Root Directory `site` → env `NEXT_PUBLIC_API_URL=https://readin-ehzw.onrender.com/api/v1`. Ignored Build Step: `git diff --quiet HEAD^ HEAD -- .`. Hobby-plan commercial-use caveat (see MANUAL_TASKS).

## Tests
Component/unit tests for formatting (size, date), fallback behaviour, `/download` redirect; Lighthouse ≥90 mobile; manual download from a clean phone.
