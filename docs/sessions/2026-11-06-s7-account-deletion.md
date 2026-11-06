# 2026-11-06 — S7.1 Account deletion — PLAN (waiting for approval: user data + small schema addition)
Stage: S7.1 (Group A)     Started from: NEXT.md (S8 merged; decisions #18: a / Cloudflare Pages / Spaceship)

## Code facts
- No deletion exists (users.routes: GET /me, PUT /push-token). User-linked collections: Book (Cloudinary
  original/converted publicIds), Annotation, Bookmark, Progress, UserData (sync docs/habits), UserFeature (trials), Job,
  Payment (keep, anonymise), AdminAudit (targetUserId only). Library delete already has the Cloudinary-delete pattern.
- App logout: `AuthNotifier.logout()` → repo.logout. No delete UI.

## Plan
Server
1. `services/accountDeletion.service.ts` → deleteAccount(userId): Cloudinary files of the user's books (errors logged, not fatal),
   deleteMany Book/Annotation/Bookmark/Progress/UserData/UserFeature/Job by userId; Payments kept for accounting/fraud but
   `email` → '' (no personal data; amount/date/plan/reference stay); audit entry "account deleted" (no e-mail); User deleted
   (→ every token stops working: protect re-reads the user). Goodbye e-mail sent first (fire-and-forget).
2. `DELETE /api/v1/users/me` {password} (protect + auth limiter; password re-check; accounts without password need
   `confirm: "DELETE"`).
3. Web (Google: deletion without the app): server page `GET/POST /delete-account` → enter e-mail → always the same answer
   → e-mail with a 1-hour link → `GET /delete-account/confirm?token=` shows what will be deleted + button → POST deletes.
   Schema: User + `accountDeletionToken`, `accountDeletionExpires` (additive, default null, no migration).
   The landing site's /delete-account (S3) links here. URL for Play Console: https://readin-ehzw.onrender.com/delete-account
   (later https://readin.micbol.org/delete-account).
App
4. Profile → Account → "Delete account" (red) → screen: what is deleted / kept, password field, type DELETE, button →
   success: local data cleared, signed out, kind goodbye. (Google Play subscriptions later: warn "cancel in Play Store".)
Tests: e2e (wrong password 401; right → all user data gone, other user untouched, payments anonymised, old token 401, login 401;
web flow incl. unknown e-mail same answer + expired link); app provider test with FakeAdapter. Docs: privacy text input for S3.

## Decided
- Michael: approve, (a) remove books from the phone too. Branch `feat/s7-account-deletion`.

## Changed
- Server: `services/accountDeletion.service.ts`, `controllers/account.controller.ts` (deleteMe, requestAccountDeletion,
  confirmAccountDeletion, isDeletionTokenValid); routes users `DELETE /me` (authLimiter), auth `/delete-account/request|confirm`;
  pages `/delete-account`, `/delete-account/confirm` (+ invalid page); User fields `accountDeletionTokenHash/Expires` (additive);
  e-mails `accountDeletionLinkEmail`, `accountDeletedEmail` (interface/service/Resend provider). Wrong password → 403 (401 would
  make the app refresh + retry).
- App: `features/account/{account_deletion.dart, delete_account_screen.dart}`, `app/app_restart.dart` + `bootstrap.dart` wrap,
  route `/account/delete`, Profile row "Delete account".
- Gotcha: Git Bash heredocs passed to python collapse `\` → `\` — use the Edit tool or a script file for backslashes.

## Tested
- Server typecheck ✅, lint 0 errors, e2e **29/29** (+3: app delete wrong pw 403 / all data gone / other user untouched / payment
  anonymised / token 401 / login 401 / goodbye mail / audit without e-mail; web flow same answer, page, bad token 400, once only;
  expired link). App: analyze ✅, flutter test **217** ✅ (+4 account_deletion_test), audit 0.
- Not tested: the screen + AppRestart on a real phone; real Cloudinary deletion (e2e books have no files).
