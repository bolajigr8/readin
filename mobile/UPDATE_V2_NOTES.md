# Update v2 — bug fixes + new reading features

## How to apply (copy & paste, safe)
1. Unzip **`readin_flutter_update_v2.zip`** over your Flutter project (say *yes* to overwrite). It deliberately does **not** contain `lib/constants/ionicons.dart` or `pubspec.yaml`, so your generated RN icon font and its `pubspec` entry stay intact.
2. **Stop the running app completely**, then:
   ```
   flutter pub get
   flutter analyze
   flutter test
   flutter run
   ```
   A full restart is required (hot reload is not enough): this update changes Android code (volume buttons) and resources (launcher icon, splash).
3. If the old Flutter icon still shows on the phone, **uninstall the app once** and run again (Android caches launcher icons).
4. **Server (for PDF import): follow `SERVER_UPDATE.md` inside `readin_server_patches.zip`.**

## Fixes (with the real cause)
| Problem you reported | Cause | Fix |
|---|---|---|
| Can import EPUB but **not PDF** ("Could not read this PDF…") | The message is from your **old, un-updated server** (the patched server words it differently). The old server's PDF check is broken and rejects *every* PDF. | **Update the server** (`readin_server_patches.zip` → `SERVER_UPDATE.md`). Meanwhile the app now offers **"Read without saving"** for that error, so PDFs are readable on the phone right away. |
| Home → empty state **"Import a Book" button does nothing** | The button was laid out outside its parent's box (my overflow hack); Flutter does not deliver touches outside the parent. | Empty/error states are normal widgets now → tappable. |
| Discover book **downloads very slowly**, error at 100 % | Gutenberg's `ebooks/N.epub3.images` link is generated on demand (slow, sometimes minutes). Also a crash when you left the screen while the download ran (`ref` used after dispose). | Downloads try Gutenberg's **static cached files first** (`/cache/epub/N/pgN-images.epub` …) and fall back to the original link. The reader's error screen now shows technical **Details** and a **Re-download** button; add-to-library no longer touches disposed widgets. *If the error still appears, send me the "Details:" line.* |
| Onboarding icon too big | — | Hero glow rings 300/210/130, icon tile 100/82, icon 38 (was 380/260/160, 130/108, 52). |
| Flutter logo as app icon + splash | Default Flutter resources were still used | RN icon (adaptive + legacy + monochrome) and a **dark splash with the ReadIn logo** are included as ready-made Android resources — no commands needed. |
| Reader → Settings: odd striped **"OVERFLOWED BY 8.9 PIXELS"** thing at the bottom right | A Flutter debug overflow banner: the Theme row (Light/Dark/Sepia) was wider than the sheet | Settings sheet rebuilt: every setting is a vertical block with equal-width chips, scrolls on small screens — cannot overflow. |
| Errors `Looking up a deactivated widget's ancestor` / many repeated `PUT /progress` | Timer fired while the reader was closing; progress flushed on every lifecycle event | Timers stop in `deactivate()`; progress uploads are throttled (≥ 10 s apart, always on pause/close). |

## New features
**Reading**
* **Volume buttons turn pages** — Volume **Down = next**, **Up = previous** (EPUB and PDF). Toggle: Reader Settings → *Volume Buttons Turn Pages*. Normal volume returns when you leave the book.
* **Keep screen on** while reading (no more screen dimming mid-page).
* **Progress scrubber** — drag the slim bar above the page buttons to jump anywhere in the book (EPUB after pages are measured, PDF immediately).
* **Time left** — "`45% · ~2h 10m left`", estimated from *your* pace in this session.
* **Search in book** — table-of-contents drawer → search box → results with highlighted excerpts; tap to jump.
* **Dictionary** — select a single word → **Define** (definitions, examples, synonyms; needs internet).
* **Copy quote** — select text → **Copy**.
**Typography & comfort** (Reader Settings)
* Line spacing (Tight / Normal / Relaxed / Airy), margins (Narrow / Medium / Wide), alignment (Left / Justified), **Paged ⇄ Scroll** layout, **Night** theme (pure black), **Dimmer** slider (darker than the phone's minimum brightness).
**Motivation**
* **Daily reading goal** card on Home: progress ring, 🔥 streak, last-7-days bars; goal-reached toast. Set the goal in Profile → *Daily Reading Goal* (5–180 min). Data stays on the phone.
**Audio**
* **Sleep timer** (Off / 15 / 30 / 60 min) in the audio player.

## Tests
`flutter test` — new `test/features/features_v2_test.dart` (time-left format, prefs, dictionary parsing/cleaning, streak + goal logic, Gutenberg mirrors, old-server PDF fallback, progress-sync throttle, sleep timer).

## Manual checks
1. Home (empty library): tap **Import a Book** (both the orange card and the outlined button in the empty state) → import screen opens.
2. Import an EPUB → works. Import a PDF → (old server) dialog "Your server rejected this PDF…" → **Read without saving** opens it; after the server update the PDF imports normally.
3. Discover → add a book → downloads noticeably faster; open it; progress shows "Downloading… NN%". Leave the screen mid-download: no crash.
4. Open a book → press **Volume Down / Up**: pages turn, system volume bar does **not** appear. Settings → switch it off → volume works normally.
5. Settings sheet: scroll it; change Theme / Line spacing / Margins / Alignment / Paged-Scroll / Dimmer; text restyles without losing your place; no overflow stripes anywhere.
6. Drag the scrubber → page jumps; after ~2 min of reading the "~… left" estimate appears.
7. TOC drawer → type a word → results → tap one. Select a word → **Define** / **Copy**.
8. Home → goal ring grows while you read (updates every 30 s and when you close the book).
9. Audio: set a 15-min sleep timer; chips highlight.
10. Launcher shows the ReadIn icon; cold start shows the dark splash with the logo.
11. Onboarding hero is clearly smaller.

## Known limits / unverified
* Nothing here was compiled or run by me (no Flutter SDK). Please run `flutter analyze` / `flutter test` and send me output.
* In-book search and "Define" need epub.js `Section.find` / internet; PDFs have no search/define/highlights yet.
* Volume keys only work while a book is open and no panel is open; they are Android-only.
* Wake lock uses the browser Screen Wake Lock API inside the reader's WebView (EPUB only; PDF keeps the system timeout).
