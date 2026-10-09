# ReadIn Flutter — Phase 7 (Import from phone + download manager)

Apply on top of Phases 1–6: unzip over the project root, then
```
flutter pub get      # adds file_picker
flutter analyze
flutter test
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
**Server:** deploy the patched `files.controller.ts`, `upload.middleware.ts`, `rateLimit.middleware.ts` from the pack
(Step A of MASTER_TRACKER) and set `CONVERSION_ENABLED=false`, Cloudinary → *Allow delivery of PDF and ZIP files*.
Without them uploads answer "Unsupported file type" or PDFs download as 401.

## What was added
| File | Purpose |
|---|---|
| `features/import/screens/import_screen.dart` | the "Import a Book" modal (UI_SPEC §4.11) |
| `features/import/widgets/dashed_border.dart` | dashed rounded border (RN `borderStyle: dashed`, 6/6) |
| `features/import/data/import_models.dart` | `PickedBook`, `validatePicked`, `titleFromFileName`, `mapUploadError`, `LocalReadRequest`, `UploadedBook`, 100 MB constant |
| `features/import/data/book_picker.dart` | `file_picker`, `FileType.any`, **extension** validation (never MIME) |
| `features/import/data/import_service.dart` | magic-byte `verify`, multipart `upload`, `storeLocalCopy`, `saveLocalOnly` |
| `library/data/services/download_service.dart` | + `importLocalCopy` (.part → magic bytes → atomic rename) and `saveLocalOnly` |
| `core/api/api_client.dart` | `postMultipart(contentType:)` |
| `widgets/confirm_dialog.dart` | + `showAlertDialog` (single button, = RN `Alert.alert`) |
| router | `/import` → `ImportScreen`; `/reader/local` receives a `LocalReadRequest` in `extra` |
| tests | `test/features/import_test.dart`, `test/helpers/test_rig.dart` |

## Flow (exactly what happens)
1. Tap the drop zone or **Select File** → system picker (any file type).
2. Extension must be `pdf`/`epub` else **"Please choose a PDF or EPUB file."**; > 100 MB → **"File too large (max 100 MB)."**; empty → "This file is empty."
3. Magic bytes (`%PDF-` / `PK`): a renamed `.txt → .epub` → **"This file does not look like a valid EPUB. It may be corrupted."** — nothing is uploaded.
4. `POST /files/upload` multipart field `file`, original file name, content type `application/pdf` | `application/epub+zip` (what the server's multer filter + `resolveFormat` expect), progress shown as "Uploading… NN%".
5. On **201**: the picked file is copied to `books/<bookId>.<ext>` (opens instantly and offline, no re-download), library refreshed, toast `"<title>" is ready to read!` (title = file name, `_` → space, same as the server), modal closes and the **Library** tab opens.
6. Errors (alert titled "Import Error"): 400 → server message · 403 → *Library Limit Reached* dialog with **Upgrade** → Profile · 413 → "File too large (max 100 MB)." · 429 → "Too many uploads. Try again later." · offline/timeout → dialog offering **Read without saving** (copies the file to `books/local/…`, opens `/reader/local` with the `LocalReadRequest`; annotations/progress stay off there — Phase 8/9).
7. Cancelling the picker is silent. While uploading, the close button and system back are disabled (the upload can't be orphaned).

## Deviations
1. Only **two** format cards (PDF / EPUB), laid out as two equal-width cards (RN had five at 28 %).
2. Callout copy is the new "Files stay on your phone…" text; RN's "Scanned PDFs are not supported" is gone (conversion on hold).
3. During upload the zone title shows progress ("Uploading… 42 %"); RN had no progress.
4. RN's `read-upload` (local-only) and `upload` are merged into this one modal, as specified.
5. `Read without saving` is new (only offered when the failure is network-related).

## Parity table
| RN `upload.tsx` | Flutter | |
|---|---|---|
| scroll padding 24, gap 28; header row (title 26 Bold, sub 14/20 mt 4; close 34×34 r10 elevated, `close` 20, mt 4, gap 16) | ✓ | ✓ |
| "SUPPORTED FORMATS" 11 SemiBold ls 1 muted, gap 12 | ✓ | ✓ |
| Format card: surface, border colour@`35`, r10, p12, centred, gap 6; icon tile 40 r10 colour@`18`, icon 20; ext 13 Bold; note 10 muted | ✓ | ✓ |
| Callout: amber400 @`12` / border @`35`, r10, p14, gap 10, icon 18, text 13/20 secondary with SemiBold lead | ✓ | ✓ |
| Drop zone: surface, 2 px dashed primary500@`40`, r16, py 32, gap 8; 72 circle @`15` + `cloud-upload-outline` 40 (mb 4); title 17 SemiBold; sub 13 secondary; busy opacity .6 | ✓ | ✓ |
| Button lg full width, spinner while busy | `AppButton` | ✓ |
| "Maximum file size: 100 MB" 12 muted centred | ✓ | ✓ |

## Manual tests (needs the patched server)
1. Home → **Import a Book** (or Library `+`, or the FAB). Pick a real **EPUB** from Downloads → progress → toast → Library shows it with the right title, **no cover** fallback initials. Open it in airplane mode later (Phase 8): the file is already on disk.
2. Same with a **PDF**, and with a file from **Google Drive** (picker downloads it first).
3. Pick a `.txt` → "Please choose a PDF or EPUB file." Rename a text file to `.epub` and pick it → "This file does not look like a valid EPUB…" (no network call).
4. Pick and cancel the picker → nothing happens, no alert.
5. As **bob** (10 books, free) import → *Library Limit Reached* → Upgrade → Profile tab.
6. Turn on airplane mode → import → "Upload failed…" dialog → **Read without saving** → reader placeholder shows `LOCAL · <title>`.
7. Debug check: `adb shell run-as com.micbol.readin ls files/books` → `<bookId>.epub|pdf`, no `.part`.
8. Delete the book in Library → the local file is removed too.
9. Tapping the back/close while "Uploading…" does nothing; afterwards it works.

## Not verified
No Flutter SDK on my side (nothing compiled/run). If `flutter pub get` complains about `file_picker`, send me the message (I can pin another version).
