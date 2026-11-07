# APK landing page (`project/site`, deployed on Vercel as a SEPARATE project from the admin)

> **Current (2026-11-06, DECISIONS #19):** `project/site` is a **Next.js 16.4.3 app like the admin** (App Router, TypeScript,
> Tailwind 4, `motion` for animations, `geist` + Fraunces fonts, `lucide-react` icons) built as a **static export** (`out/`)
> and hosted on **Cloudflare Pages** (free, commercial use allowed). A short-lived plain-HTML version came first; its text was ported.
>
> * Commands (in `project/site`): `pnpm install`, `pnpm dev` (preview at http://localhost:3000), `pnpm run typecheck`,
>   `pnpm run lint`, `pnpm build` (→ `out/`). Checks: `node tool/site_check.mjs` (324 checks on `out/`) and
>   `node tool/site_browser.mjs` (13 tests in Edge, phone width, light/dark, link clicks, theme switch, release.json;
>   `SITE_SHOTS=<dir>` saves full-page screenshots). `bash tool/verify.sh --only site --reader` runs all of it.
> * Content: `src/app/page.tsx` (home: hero with phone mock-up + floating cards, format marquee, bento features, how it
>   works, privacy, FAQ, final CTA), `privacy/`, `terms/`, `delete-account/`, `not-found.tsx`. Static files in `public/`
>   (`release.json` drives the download buttons, `_headers` = security headers incl. CSP with 'unsafe-inline' scripts —
>   static export cannot use nonces).
> * Gotchas: Links use `prefetch={false}` (Next 16.4 static export writes segment-prefetch files at a different path than
>   the client asks for → 404s); the theme class is set by an inline script before paint; `<noscript>` shows the
>   scroll-in sections when JavaScript is off; no fake reviews or invented numbers.
> * **Prices section (S9.2, 2026-11-07)**: `components/pricing.tsx` fetches `/config/public` WHILE BUILDING (force-cache +
  `?build=<time>`; Next refuses no-store in a static page) and `pricing-live.tsx` refreshes it in the browser (CSP
  `connect-src` allows the API). API unreachable → build-time prices stay; payments off → section hidden. `SITE_PRICES=off`
  skips the build fetch. Browser tests answer the API themselves (`apiReply` in `tool/site_browser.mjs`).
> * **Cloudflare (2026-11-07): use PAGES** (Create application → bottom link *Looking to deploy Pages? Get started* → Import Git):
  root directory `site`, preset *Next.js (Static HTML Export)*, build `pnpm build`, output `out`, `NODE_VERSION=22`; custom domain
  `readin.micbol.org` = one CNAME at Spaceship (DNS stays at Spaceship; Resend records untouched). Pages ignores `wrangler.jsonc`.
> * **Backup: Workers** (Cloudflare's default screen now creates a *Worker*): `site/wrangler.jsonc` serves `out/`
  as static assets. Create application → Import repository `bolajigr8/readin` → project name `readin` → Build command
  `pnpm build` → Deploy command `npx wrangler deploy` → Advanced settings: Path `/site`, build variable `NODE_VERSION=22`.
  Domain: Worker → Settings → Domains & Routes → Add → Custom domain `readin.micbol.org` (needs micbol.org on Cloudflare DNS;
  otherwise use the `readin.<account>.workers.dev` address or move micbol.org's nameservers to Cloudflare).
>
> (Older notes below.)

## Built 2026-11-06 (S3.1/S3.2) — what exists now

Plain HTML + one CSS file + one small script. **No build step, no packages.** Hosted on **Cloudflare Pages**
(free, commercial use allowed — DECISIONS #18). Pages: `/` (home, install guide, FAQ), `/privacy`, `/terms`,
`/delete-account` (explains in-app deletion; the web flow itself runs on the API server:
https://readin-ehzw.onrender.com/delete-account). Cloudflare serves `privacy.html` at `/privacy` automatically.

* **New release:** edit `release.json` only (`playUrl`, `apk.url`, `version`, `date`, `sizeMb`, `sha256`) — the home page
  buttons switch from "coming soon" to real download links. No code change.
* **Check before every deploy:** `node tool/site_check.mjs` (links, required texts, no external resources) and
  `node tool/site_browser.mjs` (opens every page in Edge/Chrome at phone width: no errors, no sideways scrolling).
* `_headers` = security headers (Cloudflare Pages). `404.html` = not-found page.
* Legal texts are drafts written by Claude Code — Michael reviews them (a lawyer if possible) before launch.
  Keep `/privacy` in step with the Play Console Data safety answers and with what the app really does.

## Deploy (Michael, once)
Cloudflare dashboard → Workers & Pages → Create → Pages → **Connect to Git** → repo `bolajigr8/readin` → production branch
`main` → Framework preset **None** → Build command **(empty)** → Build output directory **`site`** → Save and Deploy.
Then Custom domains → `readin.micbol.org` → add the CNAME record it shows at **Spaceship** (DNS for micbol.org).


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
