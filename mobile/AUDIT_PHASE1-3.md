# Audit of Phases 1–3 against the RN source (line-by-line)

Method: every Flutter widget was compared with its RN file (`Button`, `Input`, `EmptyState`, `LoadingSpinner`,
`ToastContext`, `onboarding.tsx`, `login.tsx`, `register.tsx`, `forgot-password.tsx`), `tailwind.config.js`
(radius md = 12, Tailwind line heights text-sm 20 / base 24 / lg 28 / 2xl 32 / 4xl 40) and `UI_SPEC.md`.
No device was available → numbers were verified in code, not by screenshot.

## Bugs fixed
| # | Severity | Problem | Fix |
|---|---|---|---|
| 1 | **High (visual)** | Every `FontWeight` was faked: `GoogleFonts.inter().copyWith(fontWeight)` keeps the Regular file → blurry faux-bold, wrong glyph widths | `AppTypography.label` now calls `GoogleFonts.inter(fontWeight: …)` |
| 2 | **High (behaviour)** | Onboarding `PageView` used `ClampingScrollPhysics` → no page snapping (pages stop half-way) | `PageScrollPhysics(parent: ClampingScrollPhysics())` |
| 3 | **Security (server)** | `/auth/google` trusts client-supplied email → account takeover | App sends `idToken`; server fix in `server-patches/GOOGLE_AUTH_FIX.md` |
| 4 | Medium | Password eye icon sat 10 px left of RN position | Container right padding 6 + 10 px hit-slop padding |
| 5 | Medium | Toast had no shadow; slide was a plain ease, not spring-like | shadow (0,4,8,.3), `easeOutBack` 350 ms slide, 200 ms fade |
| 6 | Low | Register error banner radius 10 (RN `rounded-md` = 12; login stays 10) | `ErrorBanner(radius:)` |
| 7 | Low | Register/forgot: missing Tailwind line heights (back 20, subtitle 24, link row 20) → text 3–7 px shorter | added |
| 8 | Low | `EmptyState` shrank to content width inside a `Column` | `SizedBox(width: infinity)` |
| 9 | Low | Skip button: hit-slop was added as layout padding → text 12 px lower/left | position compensated |
| 10 | Safety | Constants named `import` / `library` (Dart built-in identifiers) | renamed `importBook`, `libraryTab`, `libraryList` |
| 11 | Safety | `file_picker` added too early | removed until Phase 7 |

## Verified identical (code level)
Colours/alphas (glow 08/12/1E, dots 40, tile 15/25/30, badge 20/40, toast 18/40, banner 18/40 login · 1A/4D register,
success circle 33) · paddings and gaps on onboarding/login/register/forgot · input 56 px, label 14/20, error 12/16 ·
button paddings/radii/font sizes · empty state 96/72 rings, 24 px ring→title gap · spinner sizes · all copy strings and
validation messages · stagger 420 ms/80 ms/24 px · CTA 56/r14 · dots 6→24×4 · counter 12 muted.

## Known, intentional deviations (≤1–2 px or better than RN)
* Button `loading`: height stays constant (RN shrinks 4 px while spinning → layout jump).
* Inter comes from `google_fonts`: first launch needs internet (else system font until cached).
* Text line-box: Flutter vs RN distribute leading slightly differently → ≤1 px vertical difference.
* Toast spring is an `easeOutBack` approximation.
* Email is trimmed before the regex check on login/register/forgot.
* "Forgot password?" / "Sign up" links have no extra hit-slop (RN has 8 px).

## Still unverified
Nothing has been compiled or run (no Flutter SDK in my sandbox). `ionicons ^0.2.2` is the only dependency whose
version I could not cross-check with KoboWise; if `flutter pub get` complains, tell me the message.
