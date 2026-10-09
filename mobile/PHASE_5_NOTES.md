# ReadIn Flutter — Phase 5 (library data layer · Home · My Library)

Apply on top of Phases 1–4: unzip over the project root, then
```
flutter pub get      # no new packages
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
Server: for the reader/format logic to work best, deploy the patched `library.controller.ts` from the pack
(it adds `originalFormat`, `gutenbergId`, `description`, `originalFileUrl` to `GET /library`).
The app still works on the old server — the format is then inferred from the file URL (`.pdf` / `.epub`).

## What was added
| Area | Files |
|---|---|
| Models | `features/library/data/models/book.dart` — `Book`, `BookProgress`, `LibraryMeta`, `LibraryResponse`, `BookDetail` (tolerant parsing; `format`, `readableUrl`) |
| Data | `data/datasources/library_remote_datasource.dart`, `data/repositories/library_repository.dart` (fetches **all** pages: server caps `limit` at 50) |
| Logic | `utils/library_logic.dart` — `sortBooks`, `filterBooks`, `selectContinueReading`, `SortKey` (pure, unit-tested) |
| Providers | `providers/library_providers.dart` — `libraryProvider` (2-min keep-alive, refetch on user change, no fetch when signed out), `continueReadingProvider`, `processedBooksProvider`, search/sort/columns state, `deleteBookProvider`, `refreshLibrary(ref)` |
| Widgets | `book_cover.dart` (image + fallback), `book_card.dart` (sm/md/lg + `ProgressTrack`), `book_grid.dart`, `continue_reading_banner.dart` |
| Screens | `screens/home_screen.dart`, `screens/library_screen.dart` (replace the placeholders) |
| Other | `utils/insets.dart`, router wiring (`reader/:id` receives the `Book` via `extra`), Profile placeholder now hosts the dev tools (toast / dialog / sheet / gallery) |
Removed everything about upload-progress cards and conversion states.

## Decisions / deviations
1. **"Continue Reading" title** gets the same 16 px side padding as "Recent Books" (in RN it is flush with the screen edge — looks like a bug).
2. **Greeting count** reads "You have N books" exactly like RN (also "1 books").
3. **Home empty/error states** reproduce RN's quirk of an `EmptyState` (min-height 300) inside a 180/220 px box: content starts at the top and overflows downward into the 120 px bottom padding (done with an `OverflowBox`, no overflow errors).
4. **Library grid** is built from manual rows (not `SliverGrid`) so cards keep their natural height, top-aligned, with 12 px gaps — same as RN's FlatList.
5. **Sort dropdown** uses an `OverlayPortal` anchored at `top: 38` of the sort button; tapping outside closes it (RN did not; harmless).
6. **Delete** shows the confirm dialog, calls the API, refreshes; on failure an error toast (RN failed silently). Local file deletion is a TODO for Phase 7.
7. **Pull-to-refresh** spinner: primary500 on a white circle (RN Android default).
8. Cover images use `cached_network_image`; broken URLs fall back to the coloured initials cover.
9. Sorting by title/author is case-insensitive `compareTo` (RN `localeCompare`); accents may order slightly differently.
10. Reader route is still a placeholder showing `reader/<id> · <title> · <pdf|epub>` — it proves the book object and format arrive.

## Parity table
| RN | Flutter | |
|---|---|---|
| Home: padTop 20 / bottom 120 / gap 28, greeting 22 SemiBold + name 22 Bold primary500 + 👋, sub 14 secondary | `HomeScreen` | ✓ |
| Action card: primary500, r14, p16, gap14, 44 tile (white@20 %) `book-outline` 24, title 16 / sub 12 (white@75 %), chevron 18; copy "Import a Book / PDF or EPUB — opens instantly"; "Convert PDF" card removed | `_ImportActionCard` | ✓ |
| Section titles 17 SemiBold, "See all →" 13 Medium primary500, horizontal list of 6 `sm` cards, gap 12 | ✓ | ✓ |
| FAB 56, right 20, bottom `max(inset,16)+16`, shadow primary@40 % blur 12 y 4 | ✓ | ✓ |
| BookCard sm 120/156/12/11/p8/r10 · md 180/13/12/p10/r12 · lg 220/15/13/p12/r14; gap 8; title 2 lines lh 18; author 1 line; file size (sm) 10 muted; progress 3 px; completed badge 20 on black@60 % | `BookCard` | ✓ |
| Cover fallback: colour@25(hex)/@40 border, 60 % glow @30, initials 28 Bold, icon 20 @60 | `CoverFallback` | ✓ |
| ContinueReadingBanner: 68×88 r8 cover (initials 18), badge row 11 Medium ls .5, title 15/20, author 13, 4 px progress + "NN%" 12 SemiBold w34, chevron 18, border primary@30 | ✓ | ✓ |
| Library: search bar (mx16 mt12 p12/10 r10 gap 8), toolbar (sort / count / toggle), dropdown (elevated, borderLight, r10, min 140, rows 14/11, active @12 + check), toggle 34×32 (active @20), freemium banner (amber@12/@35, r10), grid 2/1 columns, empty/no-results/error/loading states with exact copy | `LibraryScreen` | ✓ |
| Book count "N book(s)" 13 muted | ✓ | ✓ |
| Long-press → "Delete Book" / `Remove "…" from your library? This cannot be undone.` Cancel / Delete | ✓ | ✓ |

## Manual tests (seed accounts: `npm run seed`)
| Account | Expect |
|---|---|
| **alice** (empty) | Home: "Start reading or add books to your library", empty card "No books yet" with *Import a Book* button; Library: "Your library is empty" + button; no freemium banner |
| **bob** (10 books, free) | Home shows 6 recent cards + "See all →"; Library shows 10, **amber banner** "10-book limit reached. Upgrade to Premium…" (tap link → Profile tab, ✕ hides it) |
| **carol** (premium) | Books shown, **no banner**, drawer badge PRO |
Then for any account with books:
1. Search "austen"/part of a title → list filters, count updates; ✕ clears; nonsense → `No results for "…"`.
2. Sort: Recent / Title / Author / Last Read; dropdown shows ✓ on the active row; tap outside closes.
3. Grid ⇄ list toggle (1 column cards full width).
4. Long-press a card → confirm → Delete → card disappears, count drops (alice-style empty state returns after the last one). Cancel does nothing.
5. Pull down on Library → spinner → list refreshes. Airplane mode + pull → stays on the old list (no crash); cold start offline → "Could not load library" / "Try Again".
6. Tap a card → reader placeholder shows the book title and `pdf`/`epub`.
7. Sign out → sign in as another user → the **other user's** books load (cache is per-user).
8. Home "Continue Reading": needs a book with 0 < progress < 99 (set one via `PUT /progress/:bookId` or the RN app) → banner shows %.
