# ReadIn Flutter — Phase 4 (shell: tabs · header · drawer · shared widgets)

Apply on top of Phases 1–3 (+ the audit fixes): unzip over the project root, then
```
flutter pub get      # no new packages
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```

## What was added
| File | Purpose |
|---|---|
| `features/shell/home_shell.dart` | `StatefulShellRoute.indexedStack` shell: tabs + bar + drawer overlay + system-back handling |
| `features/shell/app_tab_bar.dart` | RN bottom bar (stock style, not KoboWise's notched bar) |
| `widgets/app_header.dart` | `AppHeader(title, rightContent)` |
| `widgets/app_drawer.dart`, `providers/drawer_provider.dart` | Drawer + `drawerOpenProvider` |
| `widgets/loading_spinner.dart`, `confirm_dialog.dart`, `bottom_sheet_scaffold.dart` | shared widgets (`showConfirmDialog`, `showAppBottomSheet`) |
| `features/placeholder/tab_placeholders.dart`, `home_placeholder_screen.dart` | temporary tab bodies (Library has a state-test counter; Home has buttons to try toast / dialog / sheet) |
| `core/services/router.dart` | tabs are now 4 shell branches |

## Decisions that differ from the prompt (and why)
1. **Drawer lives inside `HomeShell`, not in `app.dart`'s `builder`.** The builder sits *above* the Router, so `PopScope`/back-button handling cannot see it (system back would exit the app instead of closing the drawer). Inside the shell it covers the tab bar + status bar exactly like RN's `Modal`, and back closes it first. The drawer only opens from tab headers, so nothing is lost. The mini-player slot is marked in `home_shell.dart` for Phase 10.
2. **Spring:** RN friction 9 / tension 120 → physical spring (stiffness 520, damping 28). RN's ~9 % overshoot is clamped (it would open a 28 px gap at the screen edge). Closing is critically damped. Backdrop: 250 ms in / 200 ms out, 65 % black.
3. **Active tab** comes from `navigationShell.currentIndex` instead of parsing the path.
4. Drawer **"Upgrade to Premium" → Profile tab** (that is what RN does today); the Upgrade modal arrives in Phase 10.
5. Drawer **Sign Out** has no confirm dialog (matches RN drawer). The Profile screen (Phase 9) will use `showConfirmDialog`.

## Parity table
| RN | Flutter | Status |
|---|---|---|
| Header: padTop inset+8, padBottom 14, px16, bottom border, 40×40 r10 surface menu button (menu 24), title 17 SemiBold centred 1 line, 40 px right slot | `AppHeader` | ✓ |
| Header right content: Home bell 22 secondary · Library `add` 24 primary → /import · Discover `library-outline` 22 | tab placeholders | ✓ |
| Header menu hit-slop 10 | — | ≈ not replicated (button is 40×40) |
| Tab bar: surface, 1 px top border, h `56+inset`, padTop 8, padBottom `max(inset,6)`, icons 24, label Inter Medium 11, active primary500/inactive muted, elevation 8, icon pairs | `AppTabBar` | ✓ (elevation = soft upward shadow) |
| Tab switch keeps state | `indexedStack` branches | ✓ |
| Drawer width `min(82 %, 320)`, surface, right border, backdrop .65 | `AppDrawer` | ✓ |
| Header: logo tile 34 r10 (@20/@40), "ReadIn" 18 Bold, close 34 r10 elevated `close` 22 | ✓ |
| User row: avatar 46 (@25 fill, 1.5 px @50), initials 16 Bold, name 15 SemiBold, email 12 muted, badge PRO (amber @25/@60) / FREE (border colours), 10 SemiBold ls .5 | ✓ |
| "MENU" 10 SemiBold ls 1 · items py13 px20 mv1, icon 20 in 22 box + 14 gap, 15 px label; active = primary500 + SemiBold + @10 bg + 3 px left bar (top/bottom 8, right radius 3) | ✓ |
| Upgrade card (free): mx16 my12 p14 r12, amber @10 / border @30, tile 32 r8 @20, texts 13 SemiBold / 11 @99, chevron 16 | ✓ |
| Footer: pad 20/12/20/`max(inset,16)`, sep (+20 margin ⇒ 40 inset like RN), Sign Out 18 icon + 14 Medium error500, "ReadIn v1.0.0" 11 muted | ✓ |
| Navigate: close → 120 ms → go | ✓ |
| `EmptyState` / `LoadingSpinner` | already pixel-checked in the audit; `LoadingSpinner(small:)` = 20 / 36 | ✓ |
| Alert → `showConfirmDialog`; sheet style (handle 36×4, r20, elevated, border.light, 280 ms ease-out) → `showAppBottomSheet` | new (dark-styled; RN used system Alert) | ≈ by design |

## Manual tests (Done-when)
1. Login → bottom bar shows Home active (filled icon, orange). Tap each tab; label/icon colours switch; fonts look Medium 11.
2. **State kept:** Library → tap `+1` three times → Home → Library: counter still 3.
3. Tap the already-active tab: stays/returns to its first screen (no crash).
4. Tap the ☰ button: drawer springs in from the left, backdrop fades to 65 %; tap the backdrop → closes; ✕ → closes.
5. In the drawer tap "My Library": it closes, ~0.1 s later the Library tab shows; reopen the drawer → "My Library" is orange/bold with the left bar; icon filled.
6. **System back with drawer open** closes the drawer (app stays). Back with drawer closed leaves the app (Home tab).
7. Free user (alice): amber upgrade card visible → tap → closes → Profile tab. Premium user (carol): card hidden, badge PRO.
8. Sign Out in the drawer → sign-in screen; log in again → drawer is closed.
9. Home tab: "Show toast" (toast top, slides in, auto-dismiss 3.5 s) · "Confirm dialog" (Cancel/Sign Out) · "Bottom sheet" (tap outside to close).
10. Compare header, tab bar and drawer with the RN app side by side (different phone insets: gesture-nav and 3-button-nav).

## Not verified
Still no Flutter SDK on my side — not compiled/run. `go_router` 14 APIs used: `StatefulShellRoute.indexedStack`, `StatefulNavigationShell.goBranch`. If `PopScope.onPopInvokedWithResult` is unknown on your Flutter, tell me your `flutter --version`.
