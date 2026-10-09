import '../../../core/errors/app_exception.dart';

/// 100 MB — same limit as the server (`multer` `fileSize`).
const int kMaxImportBytes = 100 * 1024 * 1024;

/// A validation / picker failure with a user-presentable message.
class ImportException extends AppException {
  const ImportException(String message) : super(message: message);
}

/// A file chosen by the user that already passed extension + size checks.
class PickedBook {
  const PickedBook({
    required this.path,
    required this.name,
    required this.size,
    required this.ext,
  });

  /// Readable path (the picker copies SAF documents into the app cache).
  final String path;

  /// Original file name including extension.
  final String name;
  final int size;

  /// `'pdf'` or `'epub'`.
  final String ext;

  /// What the server's `resolveFormat` / multer filter expect (never rely on
  /// the picker's MIME: Android reports EPUB as octet-stream).
  String get contentType =>
      ext == 'pdf' ? 'application/pdf' : 'application/epub+zip';

  /// Same rule as the server: name without extension, `_` → space.
  String get title => titleFromFileName(name);
}

/// "The_Great Gatsby.epub" → "The Great Gatsby" (server: `path.parse(name).name`
/// with `_` runs replaced by a space, trimmed; empty → "Untitled").
String titleFromFileName(String fileName) {
  final slash = fileName.lastIndexOf(RegExp(r'[\\/]'));
  final base = slash >= 0 ? fileName.substring(slash + 1) : fileName;
  final dot = base.lastIndexOf('.');
  final stem = dot > 0 ? base.substring(0, dot) : base;
  final t = stem.replaceAll(RegExp(r'_+'), ' ').trim();
  return t.isEmpty ? 'Untitled' : t;
}

/// Lower-case extension without the dot ('' if none).
String extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toLowerCase();
}

/// Validates what the picker returned. Extension decides the type (never
/// MIME). Throws [ImportException] with the RN copy.
PickedBook validatePicked({
  required String name,
  required String path,
  required int size,
}) {
  final ext = extensionOf(name);
  if (ext != 'pdf' && ext != 'epub') {
    throw const ImportException('Please choose a PDF or EPUB file.');
  }
  if (size > kMaxImportBytes) {
    throw const ImportException('File too large (max 100 MB).');
  }
  if (size == 0) {
    throw const ImportException('This file is empty.');
  }
  return PickedBook(path: path, name: name, size: size, ext: ext);
}

/// `POST /files/upload` → `{bookId, jobId, status, message}` (201).
class UploadedBook {
  const UploadedBook({required this.bookId, required this.status});

  final String bookId;
  final String status;

  factory UploadedBook.fromJson(Map<String, dynamic> j) => UploadedBook(
        bookId: (j['bookId'] ?? '').toString(),
        status: (j['status'] ?? '').toString(),
      );
}

/// Payload for reading a file without saving it to the account
/// (`/reader/local`, `extra`). Annotations/progress are disabled there.
class LocalReadRequest {
  const LocalReadRequest({
    required this.path,
    required this.title,
    required this.format,
  });

  final String path;
  final String title;

  /// `'pdf'` or `'epub'`.
  final String format;
}

enum ImportFailureKind { message, limitReached, offline }

class ImportFailure {
  const ImportFailure(this.message, [this.kind = ImportFailureKind.message]);

  final String message;
  final ImportFailureKind kind;
}

/// Maps an upload error to the right copy (hotfix `useUpload.ts` + contract).
ImportFailure mapUploadError(AppException e) {
  if (e is NetworkException || e is RequestTimeoutException) {
    return const ImportFailure(
      'Upload failed. Check your connection and try again.',
      ImportFailureKind.offline,
    );
  }
  // The ORIGINAL (unpatched) server runs a broken PDF check and answers
  // "Could not read this PDF…" for every PDF. The file is fine: offer to read it
  // locally while the server gets updated.
  if (e.statusCode == 400 && e.message.contains('Could not read this PDF')) {
    return const ImportFailure(
      'Your server rejected this PDF. This happens when the server still runs the old upload code — update it (see SERVER_UPDATE.md). The PDF itself is fine.',
      ImportFailureKind.offline,
    );
  }
  switch (e.statusCode) {
    case 413:
      return const ImportFailure('File too large (max 100 MB).');
    case 429:
      return const ImportFailure('Too many uploads. Try again later.');
    case 403:
      return ImportFailure(e.message, ImportFailureKind.limitReached);
    case 401:
      return const ImportFailure('Your session expired. Please sign in again.');
  }
  if (e.message.isEmpty) {
    return const ImportFailure('Upload failed. Check your connection and try again.');
  }
  return ImportFailure(e.message);
}
