# Deploying the admin panel to Vercel (your repo layout)

Your repository (`project/`) is a plain multi-folder repo — **not** a pnpm workspace:
```
project/
  server/   (API → Render, Docker)       has its own package.json + pnpm-lock.yaml
  mobile/   (old Expo app)               has its own package.json
  admin/    (NEW — this panel → Vercel)  has its own package.json + pnpm-lock.yaml
  package.json  (only husky + lint-staged)   .husky/pre-commit   render.yaml
```
Each folder installs and builds on its own, so the admin only needs "Root Directory = admin" on Vercel.

## 1. Put the files in the repo
1. Extract `admin_panel_FULL_v2.zip` into `project/admin` (replace files).
2. `cd admin && pnpm install` (creates/updates `pnpm-lock.yaml` — it must be committed).
3. `cp .env.example .env.local` and check `API_URL`, then `pnpm dev` and sign in at http://localhost:3000.
4. Commit and push (the root `.gitignore` + `admin/.gitignore` already keep `.env*`, `.next` and `node_modules` out).
   * Your Husky pre-commit hook also runs the **server** typecheck and the **mobile** lint on every commit. If a commit is refused because those folders' packages are not installed, run `pnpm install` inside `server` and `mobile` once (or commit once with `git commit --no-verify`).

## 2. Create the Vercel project
1. vercel.com → **Add New… → Project** → import your GitHub repository.
2. **Root Directory → Edit → choose `admin`** (this is the important part). Framework Preset shows *Next.js*. Leave Build / Install commands on their defaults (Vercel detects pnpm from the lock file).
3. **Environment Variables** (Production and Preview): `API_URL` = `https://readin-ehzw.onrender.com/api/v1`  — do **not** prefix with `NEXT_PUBLIC_`.
4. **Deploy.**
5. After the first deploy: Project → **Settings → General → Node.js Version → 22.x** (Next.js 16 needs Node 20.9 or newer), then redeploy if the build complained.
6. Open the address Vercel gives you and sign in with your admin account (created with `create-admin`). No CORS change is needed on the API.

## 3. Optional but recommended
* **Skip useless deploys:** Project → Settings → Git → **Ignored Build Step** → `git diff --quiet HEAD^ HEAD -- .` (the admin only redeploys when something inside `admin/` changed).
* **Keep the server from redeploying for admin-only commits** — in `render.yaml` under the `readin-server` service add:
  ```yaml
      buildFilter:
        paths:
          - server/**
  ```
* **New server settings** — add these to `render.yaml` under `envVars` so Render prompts for them:
  ```yaml
      - key: PAYSTACK_SECRET_KEY
        sync: false
      - key: ADMIN_EMAILS
        sync: false
      - key: GOOGLE_CLIENT_ID
        sync: false
  ```
  (`APP_URL` is already listed — it must be `https://readin-ehzw.onrender.com`.)
* **Your own domain:** Project → Settings → Domains.

## 4. Troubleshooting
| Symptom | Fix |
|---|---|
| `ERR_PNPM_OUTDATED_LOCKFILE` / "Cannot find module geist" | run `pnpm install` inside `admin`, commit `admin/pnpm-lock.yaml`, push |
| Sign-in says "API_URL is not configured" | add `API_URL` in Vercel → Settings → Environment Variables → Redeploy |
| Sign-in takes up to a minute the first time | the free Render server was asleep; try again |
| "This account is not an administrator" | create the admin with `create-admin` (see SETUP_GUIDE.md) and use that e-mail |
| Build error about Node version | Settings → General → Node.js Version 22.x |

## 5. One honest note about Vercel's free plan
Vercel's free **Hobby** plan is meant for personal, non-commercial projects. A panel that manages a paid app (Paystack revenue) is commercial, so check Vercel's current terms — the **Pro** plan is the allowed option. If you prefer to stay free, host the admin as a **second Render web service** instead (it sleeps when idle, which is fine for an admin tool):
```yaml
  - type: web
    name: readin-admin
    runtime: node
    rootDir: admin
    buildCommand: corepack enable && pnpm install --frozen-lockfile && pnpm build
    startCommand: pnpm start
    plan: free
    envVars:
      - key: NODE_VERSION
        value: 22
      - key: API_URL
        value: https://readin-ehzw.onrender.com/api/v1
    buildFilter:
      paths:
        - admin/**
```
