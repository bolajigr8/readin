# ReadIn API (`project/server`) — Express 5 · TypeScript (ESM/NodeNext) · MongoDB (Mongoose 9) · zod 4 · pnpm

Production runs on **Node 20** (Dockerfile `node:20-slim`); the `tests/*.test.mjs` runner uses `node --experimental-strip-types`, which needs **Node ≥ 22.6 locally** (`node -v`). Consider bumping the Docker image to Node 22 LTS in a later stage (test first).

Deployed on Render (free, Docker, `autoDeploy`; env in the Render dashboard — never in git). Base URL `/api/v1`.
Read the root `CLAUDE.md` first. This file = server specifics.

## Commands
```bash
pnpm install
pnpm run dev            # nodemon
pnpm run typecheck      # tsc --noEmit  (must be clean)
pnpm run lint           # eslint — must show 0 errors (warnings allowed). Global `ignores` must be its own config object.
for t in tests/*.test.mjs; do node --experimental-strip-types "$t"; done
pnpm run test:e2e       # tests/e2e/run.mjs: real server (tsx) + in-memory MongoDB + fake Paystack/Resend + dead Redis (22 tests, ~15 s;
                        # first run downloads MongoDB ~650 MB). Never loads server/.env (DOTENV_CONFIG_PATH → tests/e2e/e2e.env).
npx tsx src/scripts/create-admin.ts     # env ADMIN_EMAIL / ADMIN_PASSWORD / ADMIN_NAME
npx tsx src/scripts/remove-test-users.ts [--confirm]   # NEVER `pnpm seed` on production
```
Local run needs a `.env` (copy `.env.example`; **never read/print/commit it**). Redis is optional locally only if limiters are configured to fail open — check `config/redis.ts`.

## Layout
`src/app.ts` (middleware order matters: health → body parsers/raw-body for webhooks → cors/helmet → `generalLimiter` → routers → HTML 404 for browsers → JSON 404 → error handler; **listen first, then connect DB**) · `routes/*.routes.ts` → `controllers/*.controller.ts` → `services/*` → `models/*.model.ts` · `middleware/` (auth `protect`, `admin.middleware`, rate limits, upload, errors) · `services/email/` (templates + Resend provider) · `services/pages/pages.ts` (branded HTML pages) · `scripts/` · `jobs/` (BullMQ conversion queue, disabled by `CONVERSION_ENABLED=false`).

## Key behaviours (don't break)
* **Auth**: bcrypt passwords, JWT access 15 min + refresh; `protect` loads the user from the DB each request and rejects disabled users; plan expiry applied via `expirePlanIfNeeded`. Login requires verified e-mail (403 + message containing “verify”). `POST /auth/resend-verification` is generic (no account enumeration) and throttled per account.
* **Google sign-in**: `/auth/google` verifies a Google ID token via Google's tokeninfo (`GOOGLE_CLIENT_ID[S]`); app currently has it switched off.
* **Entitlements**: `services/entitlements.logic.ts` is pure (unit-tested): admin → feature off → blocked → `freeForAll` → gift → premium → trial. Config `AppConfig('features')` is cached 30 s (billing 15 s) and invalidated on admin writes. `/features/me`, `/features/:key/start-trial`, `/sync/:key` (versioned docs, 409 on conflict).
* **Billing/payments**: plans (kobo, NGN) in `AppConfig.billing`; `billing.logic.ts` pure + tested (limits ₦50 … ₦5,000,000, ≤6 plans). Flow in root CLAUDE.md §4. `payments.service.settlePayment` is the only place that grants Premium: verifies with Paystack, checks amount+currency, atomically claims `applied`, extends `premiumUntil`, sends the receipt. `PAYSTACK_BASE_URL` is a test-only override ignored when `NODE_ENV=production`. Paystack calls send a User-Agent; failures log `[payments] initialize failed: <status> <message> | body: <snippet>` (never the key). Admin `POST /admin/billing/test` pings Paystack.
* **Webhook** `POST /api/v1/webhooks/paystack`: raw body, HMAC-SHA512 (`x-paystack-signature`), timing-safe compare; always 200 for valid signatures (idempotent).
* **Rate limiting**: Redis store with 1.5 s timeout + 20 s circuit breaker and `passOnStoreError:true` — an Upstash outage must never take the API down. Auth limiter counts failures only.
* **Admin API** (`/api/v1/admin/*`): stats (incl. revenue), audit, config/features, billing (+test), payments, users (list/detail/patch/grant/revoke/restore/reset-trial/verify). Every mutation writes `AdminAudit`. (Roles/permissions redesign → docs/ADMIN_ROLES_PLAN.md.)
* **Pages**: `/`, `/verify-email`, `/reset-password`, `/payment/callback` are server-rendered HTML in `services/pages/pages.ts` (also used by e-mail links). E-mail links use `APP_URL`.
* Library free limit = `billing.freeLibraryLimit` (default 10) — never hard-code 10.

## Env vars (names only; set on Render / local `.env`)
Core: `NODE_ENV PORT MONGODB_URI JWT_SECRET JWT_REFRESH_SECRET CLIENT_ORIGIN APP_URL` · Redis: `UPSTASH_REDIS_URL REDIS_COMMAND_TIMEOUT_MS REDIS_BREAKER_MS` · Rate limits: `RATE_LIMIT_WINDOW_MS RATE_LIMIT_MAX_GENERAL RATE_LIMIT_MAX_AUTH RATE_LIMIT_MAX_UPLOAD RATE_LIMIT_MAX_SYNC RATE_LIMIT_MAX_ADMIN` · Mail: `RESEND_API_KEY EMAIL_FROM` · Files: `CLOUDINARY_CLOUD_NAME CLOUDINARY_API_KEY CLOUDINARY_API_SECRET TEMP_DIR MAX_CONVERSION_CONCURRENT CONVERSION_ENABLED` · Payments: `PAYSTACK_SECRET_KEY` (+ test-only `PAYSTACK_BASE_URL`), `REVENUECAT_WEBHOOK_SECRET` (unused) · Admin: `ADMIN_EMAILS` · Google: `GOOGLE_CLIENT_ID GOOGLE_CLIENT_IDS`. **Add every new variable to `.env.example` and `render.yaml` (`sync:false`).**
Fixed 2026-11-05 (S0.3): render.yaml lists every secret name (`sync:false`), `.env.example` has one `APP_URL` + the optional tuning names, the Dockerfile pins `pnpm@10.28.1`.
E-mails are sent in the background after the response (fire-and-forget) — tests must wait for them. Pre-commit hook runs `eslint --fix` (not prettier: `.prettierrc` wants semicolons but most files have none — don't mass-reformat).

## When you add things
New model/route → controller + zod validation + auth/permission + audit (admin) + rate limit scope + test + `.env.example`/docs. Pure logic goes in `*.logic.ts` with a `tests/*.test.mjs`. Schema changes affecting existing users need a migration script in `src/scripts/` that is idempotent, plus a Mongo Atlas backup reminder to Michael. Keep API responses backward compatible with already-installed app versions (APKs in the wild cannot be force-updated instantly).
