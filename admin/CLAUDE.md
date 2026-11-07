# ReadIn admin dashboard (`project/admin`) — Next.js 16 · React 19 · Tailwind 4 · TypeScript · pnpm → Vercel

> **This Next.js has breaking changes vs. your training data.** Before writing code read the relevant guide in
> `node_modules/next/dist/docs/` (see `AGENTS.md`). `next.config.ts` sets `cacheComponents:false`, `partialPrefetching:false`.

## Commands
```bash
pnpm install
pnpm dev                       # http://localhost:3000  (needs .env.local → API_URL=…/api/v1)
npx tsc --noEmit && pnpm run lint && pnpm build
node --experimental-strip-types tests/proxy-utils.test.mjs
```
Deploy: Vercel project with **Root Directory = `admin`**, env `API_URL` (server-only, NOT `NEXT_PUBLIC_`), Node 22. Steps in `DEPLOY_VERCEL.md`. A new dependency ⇒ commit the updated `pnpm-lock.yaml` (Vercel uses a frozen lockfile).

## Security design (keep it)
Browser → `/api/admin/[...path]` (route handler, `src/app/api/admin/[...path]/route.ts`) → API. Tokens live only in httpOnly, SameSite=Strict cookies `readin_admin_at` / `readin_admin_rt`; the browser never sees them. The proxy: allow-lists paths (`ALLOWED` regexes in `src/lib/proxy-utils.ts`), enforces same-origin + `x-requested-with: admin` on writes, refreshes the access token on 401 once, forwards only whitelisted query keys (`search page limit status`). **Every new admin API route must be added to `ALLOWED` and to `tests/proxy-utils.test.mjs`.** Login route accepts admin accounts only. Login/logout routes: `src/app/api/auth/*`.

## Structure
`src/app/(auth)/login`, `src/app/(app)/{dashboard,users,users/[id],features,billing,audit,guide}` (client pages using `useApi` + `api()` from `src/lib`), `src/components/ui/*` (Button, Card, Dialog, Switch, Table, Badge, Input, Label, Skeleton, Separator, NativeSelect), `components/help.tsx` (`Explain` = collapsible plain-language help, `Callout`), `components/app-shell.tsx` (sidebar), `lib/types.ts` (API shapes — money is **kobo**, show naira with `formatNaira`), `lib/utils.ts`.

## UX rules
Michael is not technical: every setting needs a plain explanation (use `Explain`/`Callout`), confirmations for risky actions (see the payments-off dialog in `billing/page.tsx`), toasts via `sonner`, loading skeletons, handle 403/401/network errors with friendly text. Mobile-friendly. Fonts via the `geist` package (no Google Fonts fetch at build).

## Testing approach used so far
`next build` + a throwaway mock API (small Node HTTP server) to exercise login/cookies/CSRF/whitelist/refresh and Playwright screenshots of each page. Recreate/commit it as `admin/tests/e2e/` when you next change auth or the proxy.

## Team & roles (S5)
Login accepts `owner`/`admin`. `AppShell` loads `/me` (role + permissions; session check) and `/stats` only with `dashboard.read`; `useCan()`; menu items have `need`; a page the person may not use shows a friendly "no permission" panel. Team page `/team` (owners). User page: Tester switch. Proxy: `me`, `team`, `team/:id`; DELETE allowed ONLY for `team/:id`.

## Planned
Releases page (S2.2), Team page + permission-aware nav (S5), later 2FA. See `project/docs/ROADMAP.md`.
