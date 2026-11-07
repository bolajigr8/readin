# 2026-11-07 — S5 admin team & roles (Michael: "proceed", plan = docs/ADMIN_ROLES_PLAN.md)

Branch `feat/s5-admin-team` (from main; `chore/site-release-1.0.1` + `chore/smaller-app` not merged yet).

## Plan (as implemented)
- Roles user | tester | admin | owner (`services/roles.logic.ts`, pure + tested): permissions list + presets; owner = all;
  admin = its `permissions[]` minus `team.manage`; `effectiveRole`: an e-mail in ADMIN_EMAILS with a verified account is
  OWNER (break-glass bootstrap — Michael never locks himself out, no migration needed to keep access).
- `requireStaff` (replaces requireAdmin) + `can('perm')` on EVERY admin route; a test reads admin.routes.ts and fails
  if a route has no `can(...)`. New `GET /admin/me` (role + permissions for the panel).
- Team API (owner only, password re-check, audit before/after, target's sessions revoked): GET/POST /admin/team,
  PATCH/DELETE /admin/team/:id. Guards: not yourself, never the last owner.
- Tester: PATCH /admin/users/:id {role: user|tester} (users.write). Tester/admin/owner = Premium-equivalent (plan in
  protect + formatUser) and every feature (evaluateAccess).
- Behaviour change: a DB `admin` NOT in ADMIN_EMAILS now gets only the permissions the owner gave it (before: 403 always).
- Migration `src/scripts/migrate-roles.ts` (idempotent, dry run by default): listed admins → owner, other admins →
  admin with all permissions except team.manage. Michael: Atlas backup first.
- Admin panel: Team page, role selector (User/Tester) on the user page, sidebar by permission, login accepts owner/admin.

## Done
- Server: commit 8348b43 (roles, requireStaff/can on every route, team API, tester, migration). typecheck ✅ lint 0 errors ✅
  unit (roles 12 + route test) ✅ e2e 36 ✅ (route-test mutation: removing one can() → fails ✅).
- Admin: login accepts owner/admin; AppShell uses /me (found: it used /stats as the session check — an admin without
  dashboard.read would have been stuck); menu by permission + "no permission" panel; Team page; Tester switch; Guide;
  proxy me/team + DELETE only for team/:id. tsc ✅ lint 0 errors ✅ build ✅ proxy test ✅; Edge screenshots (owner Team
  page; Support admin on /billing → friendly panel, menu Dashboard/Users/Guide) at 1280/390 px, no overflow/errors.
- Michael after merge: (optional) Atlas backup → `npx tsx src/scripts/migrate-roles.ts` (dry run) on Render shell — not
  required: his ADMIN_EMAILS account is an owner automatically. Then add helpers on Team; testers via Users → Tester.

## End of session (2026-11-07 evening)
- Reported S5 to Michael with merge links (site-release-1.0.1, smaller-app, s5-admin-team). Michael shut down for the day.
- NEXT.md "RESUME HERE" block lists his steps and the next-stage choices. Nothing half-done in code.
