# Parity QA — ReadIn RN vs Flutter

How to use: run the RN app and the Flutter app side by side on the **same phone size** (or emulators with the same resolution),
same account/data (`npm run seed`). For each row compare against the RN screen; write ✅ / ⚠️ + note. Items marked *code-verified*
were compared number-by-number against the RN source (padding, radius, alpha, font size, line-height, copy) during development;
*device* means it still needs your eyes (nothing was compiled by the assistant).

| # | Screen | RN source | Flutter | Code-verified | Device |
|---|---|---|---|---|---|
| 1 | Onboarding (5 slides) | `app/onboarding.tsx` | `features/onboarding/*` | ✅ + audit | ☐ |
| 2 | Login | `(auth)/login.tsx` | `auth/screens/signin_screen.dart` | ✅ + audit | ☐ |
| 3 | Register (+ success) | `(auth)/register.tsx` | `signup_screen.dart` | ✅ + audit | ☐ |
| 4 | Forgot password | `(auth)/forgot-password.tsx` | `forgot_password_screen.dart` | ✅ + audit | ☐ |
| 5 | Tab bar + header | `(tabs)/_layout.tsx`, `AppHeader` | `shell/app_tab_bar.dart`, `app_header.dart` | ✅ | ☐ |
| 6 | Drawer | `AppDrawer.tsx` | `widgets/app_drawer.dart` | ✅ | ☐ |
| 7 | Home | `(tabs)/index.tsx` | `library/screens/home_screen.dart` | ✅ | ☐ |
| 8 | My Library | `(tabs)/library.tsx` | `library/screens/library_screen.dart` | ✅ | ☐ |
| 9 | BookCard / banner / grid | `BookCard`, `ContinueReadingBanner`, `BookGrid` | `library/widgets/*` | ✅ | ☐ |
| 10 | Discover | `(tabs)/discover.tsx` | `discover/screens/discover_screen.dart` | ✅ (responsive width) | ☐ |
| 11 | Book detail | `book-detail/[gutenbergId].tsx` | `discover/screens/book_detail_screen.dart` | ✅ | ☐ |
| 12 | Import | `upload.tsx` | `import/screens/import_screen.dart` | ✅ | ☐ |
| 13 | Reader chrome | `reader/[bookId].tsx`, `ReaderToolbar` | `reader/screens`, `widgets/reader_toolbar.dart` | ✅ | ☐ |
| 14 | TOC drawer / settings / annotations / note / highlight menu | `ChapterDrawer`, `ReaderSettings`, `AnnotationsList`, `NoteEditor`, `HighlightMenu` | `reader/widgets/*` | ✅ | ☐ |
| 15 | Profile | `(tabs)/profile.tsx` | `profile/screens/profile_screen.dart` | ✅ | ☐ |
| 16 | Audio player + mini player | `audio-player.tsx`, `MiniPlayer.tsx` | `audio/*` | ✅ (mini player placement differs) | ☐ |
| 17 | Upgrade | `upgrade.tsx` | `premium/screens/upgrade_screen.dart` | ✅ | ☐ |
| 18 | Toast / dialogs / sheets / empty / spinner | `ToastContext`, `EmptyState`, `LoadingSpinner` | `widgets/*` | ✅ + audit | ☐ |

## Things most likely to differ by a pixel or two (known)
* Inter comes from `google_fonts` (first launch needs internet); leading/line-box distribution differs ≤ 1 px from RN.
* Toast/drawer springs are physical-spring approximations with the overshoot clamped.
* Reader page area is clear of the system bars at all times (RN let the text run under them when the toolbar was hidden).
* PDF scroll is continuous (RN paged).
* Android native text-selection toolbar may show together with the highlight menu.

## When something looks different
Tell the assistant: *screen · what RN shows · what Flutter shows · phone model* (a screenshot of each helps). It will compare the two source files and fix the numbers.
