# ReadIn Flutter — Phase 6 (Discover · Book detail · Add to library · Download)

Apply on top of Phases 1–5: unzip over the project root, then
```
flutter pub get      # no new packages (dio, cached_network_image, intl, path_provider already present)
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```

## API wiring (checked against the server's route files)
| App call | Server route | Notes |
|---|---|---|
| `GET https://gutendex.com/books?languages=en&page=N` (+`search=` / `topic=`) | public | **separate Dio** — no `Authorization` header, normal User-Agent, 20 s timeouts, redirects on |
| `GET https://gutendex.com/books/:id` | public | cached 1 h |
| `GET /library?page=&limit=50` | `library.routes: router.get('/')` | all pages fetched |
| `POST /library/discover` | `router.post('/discover')` (declared **before** `/:bookId`) | body = `{gutenbergId:"1342", title, author, description, coverUrl, epubUrl, language, genre}`; response `{book}` (201); **409** already added, **403** free limit |
| `DELETE /library/:id` | `router.delete('/:bookId')` | also deletes the local file |
| book file | `convertedFileUrl` (Gutenberg CDN for discover books) | downloaded with a **bare Dio** (no JWT sent to third parties) |
Server facts verified: `protect` answers **401** for missing/expired tokens (that is what triggers the refresh interceptor); a 401 on an expired token mid-session is refreshed once and retried.

## What was added
| Area | Files |
|---|---|
| Gutendex | `features/discover/data/gutenberg_models.dart` (models + `formatAuthorName`, `epubUrl`, `coverUrl`, `authorsLine`, `downloadsK`, categories), `gutendex_datasource.dart` |
| Providers | `discover_providers.dart` (paged `DiscoverFeedNotifier` per `DiscoverQuery`, kept 10/5 min; `gutenbergBookProvider` 1 h; search/category state), `add_to_library_provider.dart` (`discoverBody`, `addToLibraryProvider`) |
| Screens | `discover_screen.dart`, `book_detail_screen.dart`, `widgets/discover_book_card.dart` |
| Downloads | `library/data/services/download_service.dart` (**complete**, incl. what Phase 7 needs: `findLocal`, `delete`, `ensureLocal`, `hasValidMagicBytes`), `library/providers/download_providers.dart` (`bookDownloadProvider(bookId)`) |
| Library | `libraryGutenbergIdsProvider`, `libraryBookByGutenbergIdProvider`, `addDiscover` in datasource/repo; delete now removes the local file |

### Download rules implemented (API_CONTRACT)
1. HTTP **200 only**, redirects followed (Gutenberg `…/ebooks/N.epub3.images` redirects).
2. Written to `<id>.<ext>.part` → magic bytes (`PK` EPUB, `%PDF-` PDF) → atomic rename.
3. Stored in `<documents>/books/<bookId>.<epub|pdf>`.
4. 401/403 → `DownloadBlockedException` ("The file host refused the download…"); wrong bytes → `InvalidFileException`; other → `DownloadException` / network / timeout. Concurrent calls for one book share a single request; `.part` is removed on every failure.

## Behaviour
* **Discover:** search (400 ms debounce, ≥ 2 chars, clears category), 8 category chips (tap again to deselect), "Most Popular / category / Results for "q"" header + `N books` count, 3-column grid, infinite scroll at 50 % of a viewport, footer spinner, green ✓ badge for books already in the library, errors with *Try Again*. A failed **next page** shows a toast + "Tap to retry" (and never re-fires on every scroll event).
* **Book detail:** states `Add to Library` → `Adding...` → `In Library` (surface + green) / `No EPUB Available`; once in the library: **Read Now** (opens reader route with the `Book` in `extra`) and **Download for offline** (spinner + % + bar, "Available offline" when done, "Retry download" + message on failure). After adding, the **auto-download** setting (default on) downloads automatically. 409 → "This book is already in your library."; 403 → dialog with the server message and an *Upgrade* button (→ Profile); network → "Could not add book. Check your connection."
* *Listen Preview* is hidden behind `kListenPreviewEnabled = false` (Phase 10).

## Deviations from RN (all deliberate)
1. **Card width:** RN hard-codes 130 px, so three columns overflow a phone. Here width = `(screen − 32 − 24) / 3` and the cover keeps the 130:170 ratio.
2. **Count text** ("N books") was unstyled (black on dark!) in RN; now 12 muted as in the spec.
3. Section title gets 12 px top padding while searching (RN: touches the search bar).
4. Author saved as **"Jane Austen"** (RN stored "Austen, Jane"); `genre` is the first bookshelf without the "Browsing:" prefix.
5. The dead "Not Available" alert is reachable only via the dialog helper; the disabled button itself does nothing (as RN).
6. Detail hero fallback uses the first two letters of the title (as RN) with a 1 px colour border (RN's border had no colour).

## Parity table
| RN | Flutter | |
|---|---|---|
| Search bar (mx16 mt12, p12/10, r10, gap 8; icon 17; 15 px text; ✕ 17) | ✓ | ✓ |
| Chips: r20, px12 py7, emoji 14 + label 13 Medium, active primary@20/@60 | ✓ | ✓ |
| Section header 16 SemiBold + count | ✓ | ✓ |
| Grid 3 cols, gap 12 / 16, padding 16 / bottom 24, footer spinner | ✓ | ✓ (responsive width) |
| Card: cover r10 (fallback @20/@40, initials 28), badge 18 green + ✓ 10, title 12/17 ×2, authors (max 2) 11, `cloud-download-outline` 11 + "{n}k" | ✓ | ✓ |
| Detail: back 36×36 r10 surface@80 %, hero (pad 80/24, surface, bottom border, cover 160×210 r12 + shadow), title 24/32 Bold, authors 16, stats 13 (green "Free Forever"), buttons r12 py14 / py12, SUBJECTS ×6 (r6, 12 px) / SHELVES ×4 (primary @10/@40), attribution 12/18 | ✓ | ✓ |
| Toasts / copy: `"title" added to your library!`, "Could not add book. Check your connection.", "Not Available" … | ✓ | ✓ |

## Manual tests
1. **Discover** → popular grid appears (3 columns), count like "75,000 books". Scroll down: footer spinner, more books load (watch for no duplicates). Airplane mode on a fresh app start → "Could not load books" → turn network on → *Try Again* works.
2. Type "austen" (pause ~0.4 s) → "Results for "austen"", chips hide; clear ✕ → back to Most Popular. Tap a chip (e.g. Horror) → header shows "Horror"; tap it again → back to popular. Type 1 character only → nothing happens.
3. Open **Pride and Prejudice** → **Add to Library** → "Adding...", toast `"Pride and Prejudice" added to your library!`, button turns green "In Library", **Read Now** and download area appear; with auto-download on you see "Downloading… NN%" → "Available offline".
4. Back to Discover → the book has the green ✓ badge. Open **Library** → it is there (author "Jane Austen").
5. Verify the file really is valid: (debug) `adb shell run-as com.micbol.readin ls files/books` shows `<bookId>.epub` and **no** `.part` file; `unzip -t` on it passes.
6. Add the same book again from another account/phone → 409 toast. As **bob** (10 books) add a book → dialog "Library Limit Reached" with *Upgrade* → Profile tab.
7. Delete the book in Library (long-press) → the local file disappears too and the Discover badge is gone.
8. Open a book without an EPUB (search an unusual title) → "No EPUB Available" (disabled).
9. Turn auto-download off later (Phase 9 settings) → after adding you only get **Download for offline**.

## Known limits
* Gutendex (a free community API) can be slow or return 5xx — that shows "Could not load books" + retry.
* Not compiled/run on my side (no Flutter SDK). Please paste `flutter analyze` / `flutter test` output.
