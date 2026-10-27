# Admin account, trial rules and server security (v6)

## 1. Deploy
Copy everything under `server/src/` of this zip over your server's `src/` (new files + the changed ones:
`models/user.model.ts`, `controllers/auth.controller.ts`, `middleware/rateLimit.middleware.ts`, `app.ts`, plus the earlier PDF/format files). Commit + push; Render redeploys.
No new npm packages are needed.

## 2. Environment variables (Render → Environment)
| Variable | Value |
|---|---|
| `ADMIN_EMAILS` | **your** admin e-mail (comma-separated if you ever have more). A second lock: even a mistake in the database cannot open the admin API for anyone else. |
| `GOOGLE_CLIENT_ID` | the **Web** OAuth client id (the same one the app gets as `GOOGLE_SERVER_CLIENT_ID`). Google sign-in is now **verified with Google**; without this variable Google sign-in is refused. |
| `RATE_LIMIT_MAX_GENERAL` | optional: requests per user per 15 min (new default 600; was 200). |
| everything from before | unchanged (`CONVERSION_ENABLED=false`, Mongo, JWT secrets, Cloudinary…) |

## 3. Create YOUR admin account (only you know the password)
Run this on **your own computer** (it only needs the `MONGODB_URI` of your live database in `server/.env`), in the `server` folder:
```
ADMIN_EMAIL="you@example.com" ADMIN_PASSWORD="<paste a long random password>" npx tsx src/scripts/create-admin.ts
```
* Generate the password with `openssl rand -base64 24` and keep it in a password manager. Minimum 14 characters, 3 character types.
* The password is never printed or stored in plain text. Run the command again any time to reset it (this also signs the admin out everywhere).
* Admin accounts **cannot** be created, changed, disabled or demoted through the API — only with this script.
* Admins cannot sign in with Google (e-mail + password only).
* Then in the mobile app sign in with that e-mail/password as usual — the account is automatically unrestricted.

## 4. IMPORTANT — remove the demo accounts from the live database
The seed script created alice/bob/carol/dave @readin.test with the public password `TestPassword123!` (carol is Premium). Anyone who reads your repository can log in as them.
```
npx tsx src/scripts/remove-test-users.ts            # dry run: lists them
npx tsx src/scripts/remove-test-users.ts --confirm  # deletes them + their data
```
**Never run `npm run seed` against the live database** — it deletes and recreates data.

## 5. What was fixed / added (security + data)
* **Rate limiting bug fixed:** the server never trusted Render's proxy, so ALL users shared one IP for rate limiting (e.g. only 10 logins per 15 minutes for everybody together). `app.set('trust proxy', 1)` added.
* **Google sign-in hole closed:** the old endpoint trusted the e-mail sent by the phone — anyone could have signed in as any user, including the admin. It now verifies the Google ID token with Google.
* **Habits are saved on the server** (per user, versioned, size-limited, only the owner can read/write) so reinstalling or changing phones never loses them. Shelves/favourites/statuses sync the same way.
* **Trial is enforced on the server:** `GET /features/me`, `POST /features/habits/start-trial`. The trial clock starts once and cannot be restarted by the user. After the trial the habit data endpoints answer `403 FEATURE_LOCKED` (the data is kept, so it comes back if the user upgrades or you grant access).
* **Admin API** (`/api/v1/admin/...`, token + database-verified admin + `ADMIN_EMAILS`, rate-limited, every change written to an audit log): config (`trialDays`, on/off, included in Premium), users (search, view, plan, disable), per-user grant / revoke / restore / reset-trial, stats, audit log. This is what the Next.js admin panel will use.
* Accounts can be **disabled** (cannot sign in or refresh).

## 6. Tests
`node --experimental-strip-types tests/entitlements.test.mjs` (Node 22+) runs the trial/access rules (12 tests, passing). The TypeScript was **not compiled** by me — run `pnpm typecheck` once on your side and send me any error.

## 7. RevenueCat webhook (hardened in this version)
`POST /api/v1/webhooks/revenuecat` now: compares the secret in constant time (header may be the bare secret or `Bearer <secret>`), finds the ReadIn user among `app_user_id` / `original_app_user_id` / aliases (anonymous RevenueCat ids no longer crash it), keeps Premium after "cancellation" until the paid period really ends (`premiumUntil`), removes it on `EXPIRATION` or a refund, and ignores late, out-of-order events. Tests: `node --experimental-strip-types tests/revenuecat.test.mjs` (8 passing).
In the RevenueCat dashboard: Integrations → Webhooks → URL `https://<your-api>/api/v1/webhooks/revenuecat`, Authorization header = the value of `REVENUECAT_WEBHOOK_SECRET`.
