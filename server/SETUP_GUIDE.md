# ReadIn — setup guide (Paystack · Render · Vercel · cron)

Do the parts in order. Nothing here needs code — only copying files and filling in settings.

## 1. Update the API (Render)
1. Copy the files of `readin_server_v7.zip` over your server project (`server/src/...`, `server/tests/...`) and commit + push to GitHub. Render redeploys by itself.
2. No new npm packages are needed.

## 2. Render settings (your API service → **Environment**)
| Name | Value | Why |
|---|---|---|
| `PAYSTACK_SECRET_KEY` | `sk_test_…` now, `sk_live_…` later | lets the server talk to Paystack (never put it in the app or the admin) |
| `APP_URL` | `https://readin-ehzw.onrender.com` | the public address of your API; used in e-mail links and the payment return page |
| `ADMIN_EMAILS` | your admin e-mail | second lock on the admin API |
| `RESEND_API_KEY`, `EMAIL_FROM` | from Resend | e-mails. `EMAIL_FROM` must use a domain you **verified in Resend**, e.g. `ReadIn <hello@yourdomain.com>` — otherwise e-mails are silently refused |
| `RATE_LIMIT_MAX_GENERAL` | optional (default 600) | requests per user per 15 minutes |
| everything you already have | unchanged | Mongo, JWT secrets, Cloudinary, `CONVERSION_ENABLED=false` … |

Also in **Settings → Health Check Path** put `/api/v1/health`.

## 3. Your admin account (only you know the password)
On your own computer, in the `server` folder (with your live `MONGODB_URI` in `server/.env`):
```
ADMIN_EMAIL="you@example.com" ADMIN_PASSWORD="<a long random password>" npx tsx src/scripts/create-admin.ts
npx tsx src/scripts/remove-test-users.ts            # shows the demo accounts
npx tsx src/scripts/remove-test-users.ts --confirm  # deletes them
```
Generate the password with `openssl rand -base64 24`. Never run `npm run seed` on the live database.

## 4. Paystack
1. Create an account at **paystack.com** and open the dashboard.
2. **Settings → API Keys & Webhooks**:
   * copy the **Test Secret Key** (`sk_test_…`) into Render as `PAYSTACK_SECRET_KEY` (step 2);
   * paste this into **Test Webhook URL** and save: `https://readin-ehzw.onrender.com/api/v1/webhooks/paystack`
3. Open the admin panel → **Billing**. The Paystack badge should say *Connected · TEST mode*.
4. Add your plans (prices in ₦) → **Save plans** → switch **Show payments in the app** ON.
5. In the app: Profile → Upgrade → choose a plan → pay with one of Paystack's **test cards** (listed in Paystack's documentation under "Test payments"; no real money moves in test mode).
6. Check: the app says *Premium is active*, you get a receipt e-mail, and the payment shows as *Paid* in Billing → Recent payments.
7. **Going live:** finish Paystack's business verification, copy the **Live Secret Key** (`sk_live_…`) into Render, and paste the same webhook URL into **Live Webhook URL**. The badge then says *LIVE*.

## 5. The admin panel (Vercel — recommended)
Vercel is free, built for Next.js and never "goes to sleep"; Render's free plan does. Keep the API on Render, put the panel on Vercel.
1. In the `admin` folder run once (updates `package.json` and the lock file):
   `pnpm add class-variance-authority clsx tailwind-merge lucide-react sonner tw-animate-css geist @radix-ui/react-slot @radix-ui/react-dialog @radix-ui/react-label @radix-ui/react-switch`
2. Commit and push.
3. vercel.com → **Add New → Project** → import the repository → **Root Directory: `admin`** → Framework: Next.js.
4. **Environment Variables**: `API_URL` = `https://readin-ehzw.onrender.com/api/v1` (do **not** start it with `NEXT_PUBLIC_`).
5. Deploy, open the address, sign in with the admin account.
No CORS change is needed on the API.

## 6. The cron job (keeps Render awake) — why it failed
It was being counted as failed for two reasons: the health check could be answered with *429 Too Many Requests* (it sat behind the rate limiter), and a sleeping server takes longer than the job's time limit to wake. Both are fixed on the server. Now:
1. cron-job.org → open the job → **Enable** it again.
2. URL `https://readin-ehzw.onrender.com/api/v1/health`, method **GET**, **timeout 30 s**, success = HTTP 200.
3. Schedule `*/10 6-22 * * *` in your time zone (every 10 minutes, 06:00–22:59).
4. The very first call after the night may time out while the server wakes — that is normal; the next one succeeds. If the job still gets disabled, use **UptimeRobot** (free, 5-minute checks, it never auto-disables) with the same URL.

## 7. Quick test checklist
* Register a new account → the e-mail looks right → tap the button → a "E-mail confirmed" page.
* Forgot password → e-mail → button → "Choose a new password" page → save → sign in with the new password.
* Billing page shows *Connected*; make a test payment; Premium activates.
* Turn payments OFF in Billing → choose whether the Habit Tracker becomes free → the Profile payment section disappears in the app (pull to refresh or reopen the app).
* In the reader: change font, line spacing, margins — the text changes immediately.
