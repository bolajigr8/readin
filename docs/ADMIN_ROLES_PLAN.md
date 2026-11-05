# Admin team, roles and permissions (Michael wants FULL control, including adding other admins)

## Today (inspect the code to confirm — it may have changed)
`User.role: 'user' | 'admin'`. Admin API access = `role==='admin'` **and** (if env `ADMIN_EMAILS` is set) the e-mail is on that list (`server/src/middleware/admin.middleware.ts`). Admins are created only by `src/scripts/create-admin.ts`; there is no UI. Entitlements give admins every feature (`evaluateAccess`). No tester role, no per-admin permissions. The admin panel never shows who else is an admin.

## Target
### Roles
| role | admin panel | app features | notes |
|---|---|---|---|
| `owner` | everything incl. **Team** | all free | Michael. At least one owner must always exist. Bootstrapped from `ADMIN_EMAILS` (break-glass) |
| `admin` | only what `permissions[]` allows | all free (so they can test) | added/edited by an owner |
| `tester` | none | all features + Premium-equivalent | people helping test; no money/admin power |
| `user` | none | normal rules | |

### Permissions (strings; owner = all)
`dashboard.read` · `users.read` · `users.write` (plan, gifts, reset trial) · `users.disable` · `users.verify` · `features.read` · `features.write` · `billing.read` · `billing.write` · `payments.read` · `releases.write` · `audit.read` · `team.manage` (owner only; never grantable to `admin`)
Presets in the UI: **Full admin** (all except team.manage) · **Support** (users.read, users.verify, users.disable, payments.read, dashboard.read) · **Release manager** (releases.write, features.read, dashboard.read) · **Finance viewer** (billing.read, payments.read, dashboard.read) · Custom.

### Server
* `User` gets `permissions: string[]`, `roleChangedAt`, `roleChangedBy`. Migration script (idempotent): current `admin` whose e-mail ∈ `ADMIN_EMAILS` → `owner`; other `admin` → `admin` with all except `team.manage`.
* Middleware: `requireAdminAccess` (role owner/admin, not disabled, e-mail verified) then `requirePermission('x')` on **every** admin route (map each route; write a test that enumerates `admin.routes.ts` and fails if a route lacks a permission).
* `ADMIN_EMAILS` stays only as owner bootstrap: a listed, verified account is treated as owner at login (documented break-glass if the DB role was damaged).
* Team API: `GET /admin/team`, `POST /admin/team` {email, role, permissions} (the person must already have a verified account — else return a clear message; optional later: pending invite applied at registration), `PATCH /admin/team/:id`, `DELETE /admin/team/:id` (→ role `user`). Guards: cannot change own role/permissions, cannot remove/demote the last owner, admins cannot create owners, only owners call `team.*`.
* Sensitive actions (team changes) require **re-entering the actor's password** (bcrypt check) and are always written to `AdminAudit` with before/after.
* On any role/permission change: invalidate sessions of the target (bump `tokenVersion` or delete refresh tokens — inspect how refresh tokens are stored) so the change is immediate; `protect` already re-reads the user per request.
* `tester`: in `evaluateAccess`, treat like admin for features (and plan = premium for display) without any admin API access. `formatUser` returns `role` so the app can show a "Tester" badge.
* Admin login (BFF) must accept `owner`/`admin` only and return the permission list so the UI can hide items.

### Admin panel
* New **Team** page: table (name, e-mail, role, permissions summary, last login), **Add team member** dialog (e-mail → preset or checkboxes, each permission with a plain-language one-liner, confirm with password), edit, remove. Owner-only.
* User page: role selector (User / Tester) for people with `users.write`; shows the role badge.
* Sidebar/pages hide what the signed-in person cannot use; every page also handles `403` with a friendly "You don't have permission for this".
* Update **Guide** page (roles explained in plain words) and `proxy-utils.ts` whitelist + tests for new routes.
* Later: TOTP 2FA for owner/admin; session list; IP/last-login display.

### Tests
Permission matrix (each admin route × each role/permission preset → 200/403); last-owner protection; self-edit blocked; token revocation after role change; tester entitlements; migration idempotency; admin UI proxy tests.

### Michael's manual steps
Run the migration once on production **after** taking a Mongo Atlas backup/snapshot; confirm he can still sign in as owner; then add teammates from the Team page.
