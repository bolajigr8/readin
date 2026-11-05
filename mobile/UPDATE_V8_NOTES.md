# Update v8 — payments (Paystack), reader settings fixed, quick settings panel, offline fonts

## Reader (all verified in a real browser engine with a test book)
* **Fonts now really change.** The old code turned every font except "serif" into "sans-serif". All 8 fonts (Merriweather = default, Literata, Lora, Lexend, Atkinson Hyperlegible, OpenDyslexic, Serif, Sans) are **bundled in the app** (≈1 MB) → work offline.
* **Line spacing now changes live** (books set their own line height, which used to win). **Page margins now work** in page mode (they never did).
* **Bold is the default** text weight; the thickness slider has 4 steps (Light · Normal · Bold · Extra bold).
* **Quick settings panel** (⚙ in the reader, like your screenshot): page flipping · colour mode · font face · font size · font thickness · line spacing · text align (Left / Justified / Justified + hyphenation) · page margins · and a **General settings** button that opens the full panel.
* The reader look (font, size, spacing, margins, align, weight) is reset ONCE to the new defaults on first launch.

## Payments (Paystack, in naira)
* **Profile → Subscription / Upgrade**: plans and prices come from the admin panel (₦). Tap a plan → **Pay with Paystack** → secure Paystack page inside the app (card, bank transfer, USSD) → the app confirms with the server → Premium activates, receipt e-mailed.
* Payments one-time per period (no auto-renew). A new payment is ADDED after the Premium time still left.
* **When the admin switches payments OFF** the Subscription section, the drawer "Upgrade" card and every "Upgrade" button disappear (limit messages become plain messages). Existing Premium users still see their status.
* Profile shows the Premium end date; the free-plan book limit shown everywhere is the admin's number.
* Sign-in: if the e-mail is not confirmed there is now a **"Resend the confirmation e-mail"** button.

## Apply
1. Deploy the server (`readin_server_v7.zip`) and follow `SETUP_GUIDE.md` (Paystack keys, Render settings, admin panel).
2. Copy this project over yours, then run the commands in `COMMANDS.md`.

## Manual test list
1. Open a book → ⚙ → change font, size, thickness, line spacing, margins → the text changes immediately.
2. Tap the middle of the page → bars; tap the edges → turn pages.
3. Admin: Billing → add a plan → payments ON → app Profile shows Subscription → Upgrade → pay with a Paystack test card → "Premium is active".
4. Admin: payments OFF → app (reopen or pull to refresh) → no payment section anywhere.
5. Register a new account → the e-mail → button → "E-mail confirmed" page → sign in.
6. Forgot password → e-mail → button → choose a new password page → sign in.
