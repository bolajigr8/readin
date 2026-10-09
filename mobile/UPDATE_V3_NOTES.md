# Update v3 — local-first library, every document, share-to-ReadIn, shelves, notes, focus mode

## How to apply (copy & paste)
**Option 1 — update zip (keeps your generated icon font):**
1. Close the app. Unzip `readin_flutter_update_v3.zip` over your project (overwrite).
2. `dart run tool/patch_pubspec.dart`  ← adds `just_audio`, `crypto` and `assets/audio/` to YOUR pubspec (it does not touch the Ionicons font entry).
3. `flutter pub get` → `flutter analyze` → `flutter test` → `flutter run`
   (A full restart is required: new Android code, permissions and resources.)

**Option 2 — full project zip (`readin_flutter_FULL_PROJECT_v3.zip`):** copy everything over your project, then re-run
`dart run tool/gen_ionicons.dart --json "<…>/Ionicons.json" --ttf "<…>/Ionicons.ttf"` to get the exact RN icons back (the zip has Material look-alikes).

**Uninstall the old app once** (new launcher icon + new permissions / intent filters). Do NOT `flutter clean` unless needed (it re-downloads the PDF engine).

**Server:** deploy `readin_server_patches.zip` (`SERVER_UPDATE.md` inside) — adds `POST /library/local`, all formats. The app works with the old server too (books stay "pending" on the phone and sync after you update).

**Keep-alive WITHOUT using up the free hours** (cron-job.org): GET `https://readin-ehzw.onrender.com/api/v1/health` every 10 minutes, hours **6–22** only (≈ 527 h/month < 750 h). Details in `SERVER_UPDATE.md`.

## What's new
### One app for books AND documents (local-first)
* **Files stay on the phone.** Import = instant, works offline, no Cloudinary. The server only gets a small record (title, format, size, fingerprint) so progress, highlights, notes and bookmarks sync.
* **Formats:** EPUB, PDF (full reader) · Word `.docx`, Excel `.xlsx`, PowerPoint `.pptx`, OpenDocument `.odt`, Text, Markdown, HTML, CSV, FictionBook `.fb2`, Comics `.cbz` (viewed inside the app) · MOBI, AZW3, DOC, XLS, PPT, RTF, CBR → **Open with…** another app.
* **Import many files at once** and **import a whole folder** (scans sub-folders, up to 200 files).
* **Share → ReadIn / Open with → ReadIn** from WhatsApp, Files, Gmail, Chrome… (one file opens straight away, several go to the library). Works on a cold start too.
* **Offline-first library:** the library appears instantly from the phone's cache, even if the server is asleep or you are offline; the server is refreshed in the background; books imported offline are registered automatically later.
* Server wake-up ping when the app opens (the first request no longer waits).
* Book imported on another phone → "File not on this phone — choose the file" (matched by fingerprint).
### Organise & motivate
* **Shelves** (create/rename, add a book to many) and **statuses** (Want to read / Reading / Finished) — long-press a book; filter chips under the library search.
* **Yearly reading challenge** (Home + Profile), pace message ("2 books ahead"), **15 badges** (Profile → Badges).
* **Notes & Highlights** screen: search every note across all books, **copy**, **export as Markdown / text / .md file** (also per book from the reader's list).
* **Share a quote as a beautiful image card** (5 styles) from the selection menu or the notes screen.
### Reader
* **Fonts:** Literata, Merriweather, Lora, **Lexend** (easy reading), **Atkinson Hyperlegible**, **OpenDyslexic** (web fonts, need internet the first time).
* **Auto-scroll** (scroll layout) / **auto page turn** (paged layout): Slow / Medium / Fast. Tap the pill to stop.
* **Warm filter** (blue-light) slider · **Auto Night theme** (8 pm – 6 am) · dimmer, Night theme, line spacing, margins, alignment (from v2).
* **Focus sounds:** rain, ocean, wind, fireplace, café murmur, brown noise, pink noise — mix several with separate volumes; they stop when you leave the book.
* **Read aloud:** reads the chapter, **highlights the sentence being spoken**, turns pages and chapters by itself, speed control. A **notification with Previous / Pause / Next / Stop** (also on the lock screen) keeps it going with the screen off. The Listen-Preview audio uses the same notification.
### Other
* **Premium**: Start Premium / Restore show a "Coming soon" dialog.
* New **R + book** app icon (adaptive + themed/monochrome), dark splash with the logo, smaller onboarding hero.

## Manual test list
1. Uninstall → `flutter run`. Launcher icon = orange tile with R + book; splash = dark with the logo.
2. Import → *Select Files*: choose a PDF, a DOCX, an XLSX, a TXT and an EPUB together → summary dialog; all appear in the library.
3. Open the DOCX / XLSX (tabs per sheet) / TXT / a CSV / a CBZ comic: they render; A−/A+ and theme work; ⤴ "Open with…" works.
4. Open a `.mobi`/`.doc`: "opens in another app" screen.
5. WhatsApp → a PDF → Share → ReadIn: it imports and opens. Share three files at once → library.
6. Import → *Import a Folder* → pick a folder with books.
7. Turn on airplane mode, kill the app, reopen: library is still there; import a file offline → "will sync later"; go online and open the library → synced.
8. Long-press a book → set status, create a shelf, add it; use the filter chips.
9. Reader → Settings: fonts (Lexend/OpenDyslexic), warm filter, auto night, auto page turn, Focus sounds (rain + fireplace), Read Aloud (sentence highlighted, notification buttons work, lock the screen).
10. Select text → **Card** → pick a style → Share image. **Copy**, **Define** work.
11. Profile → Notes & Highlights: search, export, copy; Badges screen; challenge goal.
12. Premium page → Start Premium → "coming soon" dialog.

## Honest limits / unverified
* **Nothing here was compiled or run by me** (no Flutter SDK). The viewer's pure logic (CSV/Markdown/sorting) IS tested with Node (`node tool/test_viewer_core.js`), and `flutter test` has new tests for the rest. The Word/Excel/PowerPoint renderers (viewer.html) were syntax-checked but not run in a browser — send me a failing file and I'll fix the renderer.
* Android only (native code is Kotlin). Folder import copies files to a temporary cache (large folders need free space).
* Read aloud needs an EPUB (not PDF/documents). The notification asks for the Android 13+ notification permission the first time.
* Web fonts (Literata, Lexend, OpenDyslexic…) come from Google Fonts / jsDelivr: first use needs internet; if OpenDyslexic's CDN path ever changes it falls back to a rounded sans.
* Focus sounds are **synthesised** for the app (no recordings): rain/ocean/wind/noise are convincing, the café murmur is only an approximation — drop a real `assets/audio/cafe.mp3` to replace it.
* Shelves, statuses and the yearly goal are stored on the phone only (not synced between devices yet).
* Legacy `.doc/.xls/.ppt/.rtf/.mobi` cannot be rendered in-app (they open in another app).
