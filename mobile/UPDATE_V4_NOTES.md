# Update v4 — reading look copied from your reference app, About page, covers, "On this phone"

## Apply
1. Close the app. Unzip `readin_flutter_update_v4.zip` over your project (it keeps your Ionicons file).
2. `dart run tool/patch_pubspec.dart` (adds `archive` and `xml`), then `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`.
3. Full restart needed (new Android permission + native code). Android will ask for **"All files access"** only when you open *On this phone*.

## What changed (from your screenshots)
**Reading page — measured from your screenshot, not guessed**
* Page colour **#F0DEC6** (cream) with near-black text = the default ("Sepia" theme).
* Default font **Merriweather**, size 15, line spacing 1.5, side margins 32 (the reference shows ≈ 14 dp text with ≈ 1.45 spacing and ≈ 35 dp side margins), **justified + hyphenated** text. Everyone's reader look is reset ONCE to these new defaults on first launch of this version; your later changes are kept.
* New settings: **Font Thickness** (Light / Normal / Bold) and **Hyphenation**; margins are now 8 / 20 / 32.
* **The bars can no longer cover the text:** the page sits in a fixed zone between a top zone and a bottom zone. Tapping only fades the bars in/out over their own zones — the text never moves or re-flows. While hidden, a slim footer shows the chapter and **"100 of 259"** (page counter measured by epub.js; the toolbar shows it too).
* Merriweather and the other web fonts need internet the first time (then cached). Offline on first run the page uses Georgia.
**Library**
* List view = the reference's card: cover, title, author, "EPUB, 13 MB", a thin **progress line with a dot**, and quick actions **★ favourite · 🕘 want to read · ✓✓ finished · shelves · ⋮**. New **★ Favorites** filter chip.
* **Real covers & summaries for EPUBs**, read on the phone at import (title and author too — no more file-name titles). Word/Excel/etc. get a coloured tile with a format badge.
* **Tap a book → About page** (cover, quick actions, author, summary with More/Less, format & size, language, progress & last read) with **READ** and a 🔊 **Listen** button (opens the book and starts reading aloud). Continue Reading still jumps straight in.
**On this phone** (Library → second tab)
* Scans the whole phone for books and documents (PDF, EPUB, Word, Excel, PowerPoint, text…). Results are cached, searchable, filterable (PDF / EPUB / Office / Text / Other) and sortable.
* **Tap = read it right where it is** — no copy, no server, instant. Long-press to select several → **Add to library** (copies + registers, so progress/notes sync).
* Needs Android's "All files access" (you grant it once in system settings). If you'd rather not: "Pick files or a folder instead".
**Settings audit**
* The reader settings are all wired: font size / family / thickness, theme (+ Auto Night), line spacing, margins, alignment, hyphenation, paged/scroll, dimmer, warm filter, volume keys, auto-scroll, focus sounds, read aloud. Profile → Default Font Size / Theme edit the same values.
* **Reading Reminders** (was "Push Notifications") did nothing — it is now clearly marked *coming soon* until the Habit tracker exists.

## Manual test list
1. Open a book: cream page, Merriweather, justified; tap the page → bars appear WITHOUT covering or moving the text; footer shows "n of N" when hidden.
2. Settings → Font Thickness, Hyphenation, margins — text restyles live.
3. Import an EPUB: its real title, author, summary and cover show in the library and About page.
4. Library list view: quick actions work; ★ Favorites chip filters.
5. Tap a book → About → READ / 🔊.
6. Library → *On this phone* → Allow and scan → see documents → tap one to read → select a few → Add to library.

## Honest limits
* Nothing here was compiled or run by me. New native Kotlin code (device scan) and the `archive`/`xml` packages are the most likely first errors.
* Covers/summaries are extracted for **EPUB** only (PDF first-page covers and Word thumbnails are not done yet).
* "All files access" is a sensitive Android permission: fine for installing the APK yourself, but Google Play would require a justification form.
* Table-of-contents page numbers and the Contents/Bookmarks/Quotes tabs of the reference are not copied yet.
* The **Habit tracker** (calendar, daily page goals, reminders) is NOT in this update — waiting for your answers to the questions in my message.
