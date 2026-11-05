# v9 — smooth page turns, solid toasts, warnings fixed

* **Page-turn animation:** turning a page now slides with an eased 260 ms motion (like the big reader apps) instead of jumping. Tapping the edges, swiping and auto page-turn all use it; rapid taps are queued so no page is skipped; contents / search / bookmark jumps stay instant; it is switched off automatically if the phone has "remove animations" on. Choose **Page animation: Slide / None** in the ⚙ quick panel or the full settings. Verified in a real browser engine (smooth steps, same final pages as instant mode, across chapter boundaries, no errors).
* **Toasts** now have a solid, tinted background with a clear coloured border and white text — nothing shows through.
* **Analyzer:** the two unused imports are removed; the font-path test no longer depends on how Dart normalises URLs.
* The static checker (`tool/audit_dart.py`) now also finds unused / duplicate imports.

Commands: see COMMANDS.md.
