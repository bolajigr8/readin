# Update v5 — Habit tracker, open-last-book, book-only icon, speed

## Habit tracker (new)
* **Where:** sidebar → **Habits**, a card on **Home** ("Today's habits"), and Profile → Habits.
* **Several habits.** Each has: a name, a book (or "any book I read"), a **daily goal in pages** (or minutes), **days** (default **Mon–Fri**, any custom days), a **reminder time**, and an **evening nudge**.
* **Auto-tick:** while you read, forward page turns count toward every matching habit; reaching the goal ticks the day by itself. You can also **tick ✓ or fail ✗ any day by hand**, and edit the pages of a day.
* **Calendar** (Google-Calendar style): month grid with ✓ done, ✗ failed, faded ✗ missed, ○ upcoming; tap a day to edit it. "All" shows colour dots per habit; picking one habit shows big marks. **Statistics below the calendar:** current streak, best streak, month success %, days done, pages this month and in total. Rest days never break a streak.
* **Reminders (native Android, work with the app closed and after a reboot):** a notification at your chosen time with a **Snooze 15 min** button, and a 9 pm **"Don't break your N-day streak"** nudge — it is skipped if you already finished that day. Android 13+ asks for the notification permission the first time you save a habit with reminders.
## Other changes
* **Opens your last book on launch:** if you have a book in progress, the app jumps straight into it (once per launch, not when you only switch back to the app; skipped when the app was opened to import a shared file). Switch it off in Profile → *Open Last Book on Launch*.
* **Icon:** the open book only (no letter), centred — launcher icon, themed icon and the dark splash all regenerated.
* **Speed:** text styles are cached (they were rebuilt thousands of times per screen), covers are decoded at a small size, the library shows from cache instantly. **The biggest speed-up is running a release build** (debug mode is 5–10× slower): see commands.

## Manual test list
1. Sidebar → Habits → **New**: name, pick a book, goal 10 pages, Mon–Fri, reminder 2 minutes from now → Save.
2. Close the app → the notification arrives → tap **Snooze** → it returns 15 min later.
3. Read 10 pages of that book → the habit ticks itself (Home card turns ✓, calendar day gets ✓).
4. Open a past day in the calendar → mark **Failed**, then **Done**; edit pages; check streak numbers below.
5. Kill the app while a book is in progress → reopen → it opens that book. Profile → switch the option off → reopen → stays on Home.
6. Launcher icon is the book only.

## Honest limits
* Nothing here was compiled or run by me. The new native reminder code (Kotlin) is the likeliest first build error — paste it and I'll fix it.
* Pages come from the reader's measured pages (≈ 1 200 characters each): a "page" is not the printed page number. PDFs use real page numbers.
* Reminders use inexact alarms (can drift a few minutes in battery-saver mode). Habits live on this phone only (not synced between devices).
* Android may stop reminders for apps it considers "unused" or optimised: if they don't arrive, set ReadIn → Battery → *Unrestricted*.
