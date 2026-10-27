# ReadIn Admin panel

Next.js 16 · React 19 · Tailwind 4 · shadcn/ui-style components. It manages the live ReadIn API **without touching code**:
users (search, plan, disable), per-user feature access (grant days / block / reset trial), global feature settings
(on/off, trial length, included in Premium), stats and the audit log.

## 1. Install (once)
Run inside the `admin` folder (Git Bash):
```
pnpm add class-variance-authority clsx tailwind-merge lucide-react sonner tw-animate-css geist @radix-ui/react-slot @radix-ui/react-dialog @radix-ui/react-label @radix-ui/react-switch
cp .env.example .env.local
```
Open `.env.local` and set `API_URL` (default is your live API: `https://readin-ehzw.onrender.com/api/v1`).

## 2. Run
```
pnpm dev          # http://localhost:3000
pnpm lint
pnpm build        # production build check
node --experimental-strip-types tests/proxy-utils.test.mjs   # security-helper tests
```
Sign in with the **admin account** created by the server script (`server/ADMIN_SETUP.md`). The server (v6) must be deployed first.
The free API host sleeps: the first request can take up to a minute (the sign-in page tells you).

## 3. Deploy (Vercel)
* Import the Git repository, **Root Directory = `admin`**, framework Next.js.
* Environment variable `API_URL` (server-side only — do NOT prefix with `NEXT_PUBLIC_`).
* No CORS change is needed on the API: the browser only talks to this app; this app talks to the API.

## 4. How it is secured
* The browser never sees a token. Sign-in goes through `/api/auth/login`, which keeps the API tokens in **httpOnly, SameSite=Strict, Secure** cookies. Only accounts with role `admin` get a session (anyone else is signed out again immediately).
* All calls go through `/api/admin/*` (a proxy): exact **path whitelist** (no other API route can be reached), GET/POST/PUT/PATCH only, writes need the **same origin + a custom header** (CSRF), the access token is renewed with the refresh cookie, and 401 clears the session.
* The API itself still enforces everything (token + database-checked admin role + `ADMIN_EMAILS` + rate limit + audit log). The panel is just a client.
* Admin accounts can't be created or changed here (server script only).

## 5. Where things are
```
src/app/(auth)/login            sign-in page
src/app/(app)/dashboard|users|users/[id]|features|audit   the pages
src/app/api/auth/login|logout   session (cookies)
src/app/api/admin/[...path]     the secure proxy
src/lib/proxy-utils.ts          path whitelist / CSRF / cookie rules (unit-tested)
src/components/ui/*             shadcn-style components (button, card, dialog, table, switch…)
```
Add more shadcn components later with `pnpm dlx shadcn@latest add <name>` (`components.json` is included). **Do not run `shadcn init`** — it would overwrite `globals.css`.

## 6. Adding a new controllable feature later
1. Server: add the key to `FEATURE_KEYS` / `DEFAULT_FEATURES` in `server/src/services/entitlements.logic.ts`.
2. Panel: add a friendly name in `FEATURE_LABELS` (`src/lib/types.ts`). It then appears on **Features** and in every user's page automatically.

## 7. Notes
* `next.config.ts`: Cache Components / partial prefetching are turned **off** (the panel is private and fully dynamic).
* Written without being able to run Next.js here — if `pnpm dev` or `pnpm build` prints an error, send it and I'll fix it.
