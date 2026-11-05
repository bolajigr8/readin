# ReadIn 📚

> A calm, private reading app for Android — read your own books and documents, discover free classics, and keep your notes in one place.

---

## What is ReadIn?

ReadIn lets people read EPUB, PDF and everyday documents (Word, Excel, text, comics) on their phone, import books
already on the device, download free public-domain books from Project Gutenberg, keep highlights, notes and
bookmarks, build a reading habit with reminders, and listen with read-aloud. Premium is paid in naira through Paystack.

## Repository layout

| Folder | What it is | Runs on |
|---|---|---|
| `mobile/` | The app — **Flutter** (Dart), Android first (pubspec name `readin_flutter`, id `com.micbol.readin`) | phones (APK) |
| `server/` | The API — Node.js · TypeScript · Express 5 · MongoDB | Render (Docker) |
| `admin/` | Admin dashboard — Next.js 16 | Vercel (Root Directory `admin`) |
| `docs/` | Plans, decisions, history, session logs | — |

The old React-Native/Expo app was replaced by the Flutter app; its last leftovers are kept under the git tag `expo-legacy`.

## Getting started

```bash
# API (needs server/.env — copy server/.env.example and fill it in; never commit it)
cd server && pnpm install && pnpm run dev

# Admin dashboard (needs admin/.env.local → API_URL=…/api/v1)
cd admin && pnpm install && pnpm dev

# App
cd mobile && flutter pub get && flutter run
```

Run every check (server, admin, app) with `bash tool/verify.sh`. A pre-commit hook (husky; enabled by
`pnpm install` in this folder) runs fast checks for the parts you changed.

## Test accounts (local development only)

`cd server && pnpm run seed` creates demo users (`@readin.test`). **Never run the seed against production**; remove
demo users there with `npx tsx src/scripts/remove-test-users.ts --confirm`.

---

Built with ❤️ by Micbol.
