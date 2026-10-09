# ReadIn Flutter — Phases 8 + 9 (Reader · progress sync · highlights · notes · bookmarks · Profile · settings)

Apply on top of Phases 1–7: unzip over the project root, then
```
flutter pub get      # adds webview_flutter + pdfrx
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
**Server:** deploy the patched `progress.controller.ts` (adds `/progress/stats/me` fields + `{progress}` shape). Annotations/bookmarks routes already exist in your server.
**Android:** `AndroidManifest.xml` now references `res/xml/network_security_config.xml` (cleartext allowed for `127.0.0.1`/`localhost` **only** — the EPUB reader's loopback server). Both files are in the zip.

## ⚠️ Engine decision (deviation from the pack, deliberate)
The pack said "flutter_epub_viewer (fallback sakura_epub)". I could not compile-test any third-party EPUB viewer API in my sandbox, so instead the EPUB reader uses the **epub.js that already worked in the RN hotfix** (`rn-hotfix/assets/*.txt` → `assets/reader/*.js`) inside **`webview_flutter`**, fed by a **loopback HTTP server** (`127.0.0.1`, random port, random per-session token in every URL). The book is **streamed from disk** (no base64, no giant JS string), the page + scripts + book share one origin (no `file://` / CORS problems). Font/size/theme changes call `rendition.themes.*` — the page is **never reloaded**, so the reading position survives. PDF uses **`pdfrx`** (minimal API surface: `PdfViewer.file`, `goToPage`, `pageCount`, `onViewerReady`, `onPageChanged`). If you prefer `flutter_epub_viewer` I can swap the engine later: only `widgets/epub_view.dart` + `assets/reader/` are engine-specific.

## Phase 8 — what was added
| File | Purpose |
|---|---|
| `features/reader/screens/reader_screen.dart` | the reader: loading / error / ready states, overlays, immersive mode, lifecycle |
| `features/reader/providers/reader_controller.dart` | `ReaderController` + `ReaderState` (open flow, download, saved position, prefs, engine events) |
| `features/reader/data/reader_server.dart` | loopback server (page, scripts, book stream; token-guarded) |
| `features/reader/data/progress_sync.dart` | debounced progress upload with accumulated reading time |
| `features/reader/data/progress_repository.dart`, `reader_models.dart` | `GET/PUT /progress/:id`, TOC / saved-progress / prefs models |
| `features/reader/widgets/` | `epub_view`, `pdf_view`, `reader_toolbar`, `chapter_drawer`, `reader_settings_sheet`, `slide_panel`, `tap_detector` |
| `assets/reader/` | `reader.html`, `epub.min.js`, `jszip.min.js` |

**Open flow:** route `/reader/:id` (`extra` = `Book` | `LocalReadRequest` | null → `GET /library/:id`) → `DownloadService.ensureLocal` (progress "Downloading… NN%" 220×4 track) → corrupt file? magic-byte check → delete + re-download once → `GET /progress/:id` (missing/offline = start at 0) → EPUB: open at saved **CFI**; PDF: saved page (`page:N`).
**Progress sync (API_CONTRACT):** `PUT /progress/:id` every 30 s + on pause/background + on leaving the screen, body `{currentCfi, percentage 0–100, currentChapter, currentChapterTitle, totalChapters, readingTimeDeltaSeconds}`. Time since the last *successful* send is accumulated (retry keeps it), background time is excluded, one flush credits ≤ 600 s. EPUB % comes from `locations.generate(1200)` generated lazily (until then the last known % is shown/kept — progress is never overwritten with 0). Local files never call the API. Leaving the reader refreshes the library (bars + Continue Reading).
**Chrome:** tap zones 25/50/25 and horizontal swipe for pages (EPUB, inside the page), centre tap toggles the toolbar (PDF: any single tap); toolbar auto-hides after 3.5 s, fade 200 ms, never while a panel is open; hidden toolbar = immersive mode (status/nav bars hidden; page area keeps constant size). Prev/next buttons: previous/next **chapter** (EPUB) or **page** (PDF). Centre label "Chapter n of N" / "Page n of N" / "Reading…". TOC button on PDF → toast "Table of contents not available for PDFs."
**Panels (RN spring, overshoot clamped):** TOC drawer (left, `min(78 %,300)`), Reader Settings (bottom), Annotations sheet (bottom, ≤ 70 %). System back closes an open panel first.
**Settings sheet:** font size 12–28 step 2, Sans/Serif, Light/Dark/Sepia (new, with colour dots). Changes are applied live to the page and **persisted** (`@readin/reader_*` keys) — they are also the "defaults" used for the next book (Profile → Reader preferences edits the same keys).
**Errors:** "Could not open book" (📖) + message + **Go Back** (+ **Re-download** when the file is invalid/corrupt). A 20 s watchdog reports PDFs that never become ready (corrupt/password-protected).

## Phase 9 — what was added
| File | Purpose |
|---|---|
| `features/annotations/data/{annotation_models,annotations_repository}.dart` | `Annotation`, `Bookmark`, repositories using the **real shapes** `{annotations:[]}`, `{annotation}`, `{bookmarks:[]}`, `{bookmark}` |
| `features/annotations/providers/annotations_providers.dart` | `annotationsProvider(bookId)` (optimistic delete + rollback), `bookmarksProvider(bookId)` (idempotent add) |
| `features/reader/widgets/{highlight_menu,note_editor_sheet,annotations_sheet}.dart` | RN HighlightMenu / NoteEditor / AnnotationsList (+ Bookmarks tab) |
| `features/profile/…` | `ProfileScreen`, `SettingsRow/Card/Switch`, `readingStatsProvider` (5-min cache), `settingsProvider` |
| `utils/formatters.dart` | `formatReadingTime` now matches RN (`1h`, `1h 5m`, `45m`) |

**Highlight flow:** select text → menu (5 colours + Note) → colour → `POST /annotations {bookId,type:'highlight',cfiRange,selectedText≤2000,note,color,chapterTitle,chapterIndex}` → `readerApi.highlight(cfi, colour@35 %)` + toast "Highlighted!". Note → editor sheet → `type:'note'` + toast "Note saved!". Tapping a drawn highlight opens its note for editing (`PUT /annotations/:id`). Saved highlights are **re-drawn on every open** once the book is displayed and the list is loaded. Delete (trash in the list) is optimistic and rolls back on failure. **403** (free limit 20) → dialog "Annotation Limit Reached" with the server message and *Upgrade* → Profile.
**Bookmarks:** the top-bar bookmark button **toggles** a bookmark for the current location (filled/primary500 when bookmarked; `POST/DELETE /bookmarks`, idempotent per CFI); **long-press opens the Annotations list** (as specified in the Phase 9 prompt; tabs *Highlights* / *Bookmarks*; PDFs show only Bookmarks). Tapping an item jumps (`display(cfi)` / `goToPage`).
**Local files** (opened via "Read without saving"): annotation/bookmark features show the RN toast "Save to library to use highlights/notes/bookmarks/annotations." and never call the API.
**Profile:** user card, READING STATS (4 cells, from `/progress/stats/me`), SUBSCRIPTION (premium / free + usage bar `n / 10 books`), READER PREFERENCES (font size stepper, theme cycle light→dark→sepia), APP SETTINGS (notifications switch, auto-download switch — read by the add-to-library flow), ACCOUNT (email, **Sign Out** with confirm), footer + long-press dev tools (*Reset Onboarding*, *Design gallery* in debug builds). Pull-to-refresh refreshes stats. The temporary dev buttons that lived on the Profile placeholder are gone.

## Deviations / notes
1. Engine: epub.js-in-WebView instead of `flutter_epub_viewer` (see above).
2. PDF scroll is pdfrx's default **continuous vertical**; RN paged every page. Page number / % come from `onPageChanged`.
3. The **Android native text-selection toolbar** (Copy/Share) can appear together with our HighlightMenu — `webview_flutter` has no API to suppress it; our menu is shown after the selection ends.
4. Highlights are drawn with `fill-opacity .35` and normal blending (RN used `multiply`, which makes highlights invisible on the dark theme).
5. Chapter numbering uses the **TOC** (top-level entry containing the current file) instead of RN's spine index (RN showed things like "Chapter 12 of 8").
6. Active row in the TOC drawer = the top-level chapter only (RN compared sub-item indexes with the chapter number).
7. Bookmark button semantics follow the Phase 9 prompt (tap = toggle, long-press = list), not UI_SPEC's older "opens list".
8. "Download" of reader-side prefs: one set of keys serves as both the reader's current and the Profile's default prefs.

## Parity table (reader chrome)
| RN / UI_SPEC §4.12 | Flutter | |
|---|---|---|
| Top bar: h `inset+56`, pad `inset+8`/16/12, bg black-ish@.88, bottom border, 36×36 r8 surface@80 % buttons (22 icons), title 15 SemiBold centred | `ReaderToolbar` | ✓ |
| Bottom bar: px20 pt12 pb `inset+8`, border top, chevrons, label 13 secondary, `NN%` 14 SemiBold primary500 | ✓ | ✓ |
| Loading / "Opening book…" / Error (📖 48, 20 SemiBold, 13 secondary, Go Back r12 px32 py14) | `_LoadingBody`, `_OpeningOverlay`, `_ErrorBody` | ✓ |
| TOC drawer: header 16 SemiBold + 30×30 close, rows py13 px20+16·depth 14/20, active primary500@6 % + 3 px bar, "No chapters found" | `ChapterDrawer` | ✓ |
| Settings sheet: handle, title 16, rows with 30×30 tiles, stepper 24 icons / 17 value, toggles r8 px12 py8 (active border primary500 + @8 %) | `ReaderSettingsSheet` | ✓ |
| HighlightMenu: bottom 80, mx16, r16 p16, preview 13 italic (≤ 80), swatches 28 / 2 px white@20 % gap 10, divider 1×28, Note chip (@18/@40, r8), close 18, shadow | `HighlightMenu` | ✓ |
| NoteEditor: "Add Note" 17, quote box with 3 px bar (≤ 150), input 100–180, counter `n / 2000`, Cancel/Save Note | `NoteEditorSheet` | ✓ |
| AnnotationsList: ≤ 70 %, "Highlights & Notes (n)", items surface r10 p12 with 3 px colour bar, italic 13, note row, chapter 11, trash 15 error500; empty state | `AnnotationsSheet` | ✓ |
| Profile (UI_SPEC §4.13): user card 56 avatar, stats card (22 Bold / 11), subscription card + usage bar, rows (34 tile @`20`, 15/12, border @80), switches, footer | `ProfileScreen` | ✓ |

## Manual tests
**Reader**
1. Library/Discover → open an EPUB: spinner "Preparing book…" → "Opening book…" → first page **< 2 s** (from disk). Swipe / tap right 25 % = next page, left 25 % = previous, centre toggles the toolbar; toolbar fades after ~3.5 s and the status bar hides.
2. ☰ list button → TOC drawer; pick a chapter → jumps; current chapter highlighted; bottom label "Chapter n of N". ⚙ → change font size / Sans-Serif / Light-Dark-Sepia: text re-flows **without reloading** and you stay at the same spot.
3. Read a few pages, press back → Library bar/percentage updated. Kill the app, reopen the book → same paragraph. In airplane mode the book still opens (local file); progress syncs later.
4. PDF: opens at the saved page, page count in the bottom bar; list button shows the "Table of contents not available for PDFs." toast.
5. Corrupt file: replace `books/<id>.epub` with junk → "Could not open book" … **Re-download** fixes it.
6. Premium/free: none of this should differ.
**Annotations / bookmarks**
7. Select text → menu → a colour → "Highlighted!" and the highlight is drawn; close the book, reopen → **still drawn** (and after killing the app).
8. Select text → **Note** → type → *Save Note* → "Note saved!"; long-press the bookmark button → list shows it with the note; tap it → jumps; trash → disappears (and the highlight vanishes from the page).
9. Tap a drawn highlight → editor opens with the note; edit → saved.
10. Bookmark button: tap → "Bookmark added!" (icon filled); tap again → "Bookmark removed."; list → *Bookmarks* tab → tap jumps.
11. As **alice** (free) create 20 annotations, the 21st → dialog "Annotation Limit Reached" → Upgrade → Profile.
12. "Read without saving" file (Phase 7): selecting text/bookmark shows "Save to library to use …"; nothing is sent to the API.
**Profile**
13. Numbers match the server (Books, Completed, Read Time after reading for a while, Highlights = annotation count). Pull down to refresh.
14. Free plan shows "Free plan: n / 10 books used" + bar; premium shows "Premium Active". Default Font Size ± and Default Theme cycle persist; open a book → uses them. Auto-download switch off → adding a Discover book no longer downloads it. Sign Out asks for confirmation. Long-press the version text → dev tools.

## Not verified
Nothing is compiled or run (no Flutter SDK in my sandbox) — and this phase uses two new packages whose versions I could not resolve: `webview_flutter ^4.10.0`, `pdfrx ^2.0.0`. If `pub get`/`analyze` complains (e.g. a pdfrx API difference), send me the messages. Unit tests cover the models, TOC logic, progress sync (fake clock), the loopback server (real sockets), the annotation/bookmark repositories and notifiers; there are no widget tests for the screens.
