# Play Console — everything to paste (S7.4 / S7.2)

Prepared 2026-11-06 by Claude Code from the real code (Play version = flavor `play`). **Re-check after every change that adds
data, permissions, SDKs (e.g. Firebase S6, Google Play Billing/RevenueCat) and update both this file and `site/privacy.html`.**
Michael reviews, then copies the answers into Play Console. Never paste passwords into this file.

---

## 1. Store listing (Grow → Store presence → Main store listing)

**App name** (max 30): `ReadIn – Book & PDF Reader`  (26)

**Short description** (max 80):
`Read EPUB, PDF and documents, discover free classics, keep notes, build a habit.`  (80 — exactly the limit)

**Full description** (max 4000):
```
ReadIn is a simple, beautiful reading app for your books and documents.

READ ANYTHING
• EPUB, PDF, Word, Excel, PowerPoint, text and more
• Comfortable reading: font, size, line spacing, margins, themes (light, sepia, dark) — with offline fonts
• Page turns or scrolling, volume-key page turns, and your place is always saved

FREE CLASSICS
• Browse and download thousands of public-domain books from Project Gutenberg

NOTES, HIGHLIGHTS AND BOOKMARKS
• Highlight passages, add notes and bookmarks
• Create shareable quote cards
• Everything is kept in your account

BUILD A READING HABIT
• Set daily reading goals and get gentle reminders
• Follow your streaks on a calendar

LISTEN WITH READ-ALOUD
• ReadIn can read your book to you, with controls on the lock screen

IMPORT IN SECONDS
• Share a file from WhatsApp, e-mail or your file manager straight into ReadIn, or pick a folder

PRIVATE BY DESIGN
• Your imported books stay on your phone
• No ads, no tracking
• Delete your account any time, in the app or on the web

ReadIn Premium unlocks unlimited books in your library and extra features such as the reading habit tracker.

Questions? micboltech@gmail.com
```
(No prices, no links to other payment methods, no keyword lists — Play metadata policy.)

**App icon:** `docs/store/icon-512.png` (512×512) · **Feature graphic:** `docs/store/feature-graphic-1024x500.png`

**Phone screenshots** (Michael captures on the Samsung, from the PLAY version, 4–8 images, portrait, no status-bar clutter):
1. Library with a few books · 2. Reading an EPUB (sepia) · 3. Reader settings panel · 4. Discover (free classics) ·
5. Highlights/notes · 6. Habit tracker calendar · 7. Read-aloud with the notification · 8. Import ("Share to ReadIn").
Do NOT show prices, Paystack, test data with real people's names, or the "On this phone" scan (not in the Play version).

**Category:** Books & Reference · **Tags:** e-book reader, PDF reader, books · **Contact e-mail:** micboltech@gmail.com ·
**Website:** https://readin.micbol.org · **Privacy policy:** https://readin.micbol.org/privacy

---

## 2. App content (Policy → App content)

| Form | Answer |
|---|---|
| Privacy policy | `https://readin.micbol.org/privacy` |
| Ads | **No**, the app does not contain ads |
| App access | **All or some functionality is restricted** → add the reviewer login (section 4) |
| Content rating | Questionnaire answers in section 5 → expected **Everyone / PEGI 3 / 3+** |
| Target audience | **13–15, 16–17, 18 and over** (NOT under 13 → no Families policy). "Could the app appeal to children?" → **No** |
| News app | No |
| COVID-19 contact tracing | No |
| Data safety | Section 3 |
| Government app | No |
| Financial features | **My app doesn't provide any financial features** |
| Health | No health features |
| Account deletion | Section 3 (URL `https://readin.micbol.org/delete-account`) |
| Foreground service permissions | Section 6 |
| Advertising ID | **No** (the app does not use the advertising ID) |

---

## 3. Data safety (Policy → App content → Data safety)

**Data collection and security**
- Does your app collect or share any of the required user data types? → **Yes**
- Is all of the user data collected by your app encrypted in transit? → **Yes** (HTTPS only; cleartext allowed only for the
  on-phone 127.0.0.1 reader server)
- Which of the following methods of account creation does your app support? → **Username and password** (Google sign-in is off)
- Account deletion URL → `https://readin.micbol.org/delete-account`
- Can users request that some data be deleted without deleting the account? → **Yes** (books, notes, highlights, bookmarks,
  habits can each be deleted in the app)

**Data types** (Collected = sent to our server. Shared = NO for all: our providers act for us — Render, MongoDB Atlas, Upstash,
Cloudinary, Resend — which Google does not count as "sharing"):

| Category → type | Collected | Shared | Optional? | Purposes | Ephemeral? |
|---|---|---|---|---|---|
| Personal info → **Email address** | Yes | No | Required | Account management, App functionality | No |
| Personal info → **Name** (display name) | Yes | No | Required | Account management, App functionality | No |
| Personal info → **User IDs** (account id) | Yes | No | Required | Account management, App functionality | No |
| Financial info → **Purchase history** (plan, amount, date, reference) | Yes | No | Optional (only buyers) | App functionality, Account management | No |
| Files and docs → **Files and docs** (book titles, authors, file type/size, fingerprint — not the files) | Yes | No | Optional | App functionality | No |
| App activity → **Other user-generated content** (notes, highlights, bookmarks, shelves, habits) | Yes | No | Optional | App functionality | No |
| App activity → **Other actions** (reading progress) | Yes | No | Optional | App functionality | No |

Not collected (answer "No"): location, contacts, photos/videos, audio, messages, calendar, health, web history, device or other
IDs, app performance/crash logs, diagnostics. *(When S6 Firebase is added: add "Crash logs", "Diagnostics", "App interactions"
— collected, optional (consent), Analytics — and update the privacy policy.)*
*(When Google Play Billing is added: purchase history stays the same category.)*

⚠️ Server logs and rate limiting see IP addresses briefly for security. Google's guidance treats data used only for security /
fraud prevention and deleted quickly as collected-for-"Fraud prevention, security, and compliance" — if Play Console asks about
IP-derived data, choose that purpose. Re-read the in-console help text when filling it in.

---

## 4. App access — reviewer login (Policy → App content → App access)

Choose **All or some functionality is restricted** → **Add new instructions**:
- Name: `Reviewer account`
- Username: *(Michael creates a dedicated account, e.g. `playreview@…` — confirmed e-mail, not his personal account)*
- Password: *(type it only in Play Console — never in git, chat or this file)*
- Any other information:
```
1. Open ReadIn and sign in with the e-mail and password above (no 2-step verification).
2. This account has Premium, so every feature is unlocked: library, reader, notes/highlights, habit tracker, read-aloud.
3. To test reading quickly: Discover → open any free classic → Download → Read.
4. Read-aloud: open a book → tap the page → reader settings → Read Aloud → Start; the media notification appears (foreground service).
5. Account deletion: Profile → Account → Delete account (please do not delete this reviewer account).
```
Michael, before submitting: create the account in the app, confirm the e-mail, then in **admin → Users → that user → Grant
Premium** (long period, e.g. 1 year), and sign in once on a phone to be sure it works. The password must not expire.

---

## 5. Content rating questionnaire (IARC)

- Category: **Reference, News, or Educational** (e-book reader)
- Violence, sexuality, language, controlled substances, gambling, horror: **No** to all (the app ships no such content; users
  read their own files and public-domain classics)
- Does the app allow users to interact or exchange content with each other? → **No** (no chat, no public profiles; quote cards
  are shared through Android's normal share sheet)
- Does the app share the user's current physical location with others? → **No**
- Does the app allow users to purchase digital goods? → **Yes** (Premium; Google Play Billing in the Play version)
- Unrestricted internet access / web browser? → **No** (it only downloads classics from Project Gutenberg and talks to our server)
- Expected result: **Everyone / PEGI 3 / USK 0 / 3+**

---

## 6. Permissions & foreground service (S7.2)

Requested by the **Play** version (merged manifest checked 2026-11-06 — all "normal", none restricted):
`INTERNET`, `ACCESS_NETWORK_STATE`, `POST_NOTIFICATIONS` (reminders + read-aloud controls), `RECEIVE_BOOT_COMPLETED`
(re-arm reading reminders after a restart), `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`
(read-aloud), `READ_EXTERNAL_STORAGE` (only up to Android 12, for opening shared/opened files on old phones).
Since S4 (2026-11-07): `USE_BIOMETRIC` + `USE_FINGERPRINT` (added by androidx.biometric) for the optional
"Unlock with fingerprint / face" — normal permissions; the fingerprint/face never leaves the phone (Android checks it,
ReadIn only gets yes/no), so nothing changes in the Data safety form.
NOT in the Play version: `MANAGE_EXTERNAL_STORAGE` (checked by `tool/build_play.sh`). No exact alarms (reminders are inexact),
no location, camera, microphone, contacts, SMS, or `QUERY_ALL_PACKAGES`. (`android.permission.DUMP` in the merged manifest is
only a protection on androidx's profile-installer receiver, not a permission ReadIn requests.)

**Foreground service declaration** (Policy → App content → Foreground service permissions):
- Type: **Media playback**
- Description (paste):
```
ReadIn's read-aloud feature reads the user's book out loud with the phone's text-to-speech engine. The user starts it
from the reader settings (Read Aloud → Start). It must keep playing when the screen is off or the user switches apps, like an audiobook, and
it shows a media notification with play/pause/next controls. It stops when the user taps stop, finishes the book or
closes the notification.
```
- Video (YouTube unlisted or Drive link, 30–60 s): open a book → reader settings → Read Aloud → Start → press Home (app in background, audio continues)
  → show the notification + lock-screen controls → pause/resume from the notification → stop.

---

## 7. Release notes (first closed-test release)
```
Welcome to the ReadIn test! Read EPUB, PDF and documents, discover free classics, keep notes and build a reading habit.
Please tell us anything that feels confusing or broken: micboltech@gmail.com
```
