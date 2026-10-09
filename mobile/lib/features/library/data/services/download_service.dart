import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/formats.dart';
import '../models/book.dart';

/// The file host answered 401/403 (e.g. Cloudinary blocking PDF/ZIP delivery).
class DownloadBlockedException extends AppException {
  const DownloadBlockedException({super.statusCode})
      : super(
          message:
              'The file host refused the download. Please try again later or contact support.',
        );
}

/// The downloaded bytes are not a real EPUB/PDF (HTML error page, truncated…).
class InvalidFileException extends AppException {
  const InvalidFileException({String format = 'file'})
      : super(message: 'The downloaded file is not a valid $format.');
}

/// A local-first book whose file is not on THIS phone (imported on another
/// device, or the app data was cleared). The user can point the app at the file.
class MissingLocalFileException extends AppException {
  const MissingLocalFileException()
      : super(
          message:
              'This book\'s file is not on this phone. Pick the same file again to link it.',
        );
}

/// Any other download failure (HTTP status, network, cancelled).
class DownloadException extends AppException {
  const DownloadException({required super.message, super.statusCode});
}

/// Download / local-storage manager for book files.
///
/// Rules (API_CONTRACT "client-side download rules"):
/// 1. HTTP **200 only** (redirects followed) — never save an error body.
/// 2. Write to `<name>.part`, check magic bytes (`PK` EPUB, `%PDF-` PDF)
///    **before** the atomic rename to the final name.
/// 3. Final path: `<documents>/books/<bookId>.<epub|pdf>`.
/// 4. 401/403 → [DownloadBlockedException].
class DownloadService {
  DownloadService({Dio? dio, Future<Directory> Function()? documentsDir})
      : _documentsDir = documentsDir ?? getApplicationDocumentsDirectory,
        // Separate Dio: no auth interceptor — the JWT must not reach hosts.
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 60),
                followRedirects: true,
                maxRedirects: 10,
                headers: const {
                  'User-Agent': 'ReadIn/1.0 (Flutter; Android) Dart/3',
                  'Accept': '*/*',
                },
              ),
            );

  final Dio _dio;
  final Future<Directory> Function() _documentsDir;

  final Map<String, Future<File>> _inFlight = {};
  final Map<String, CancelToken> _tokens = {};

  // ── paths ───────────────────────────────────────────────────────────────────

  Future<Directory> booksDir() async {
    final base = await _documentsDir();
    final dir = Directory('${base.path}${Platform.pathSeparator}books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// `…/books/<bookId>.<ext>` (the file may not exist yet).
  Future<String> localPath(String bookId, String format) async {
    final dir = await booksDir();
    return '${dir.path}${Platform.pathSeparator}$bookId.${_ext(format)}';
  }

  Future<bool> isDownloaded(String bookId, String format) async =>
      (await localFile(bookId, format)) != null;

  /// The local file if it exists and is non-empty.
  Future<File?> localFile(String bookId, String format) async {
    final f = File(await localPath(bookId, format));
    try {
      if (await f.exists() && await f.length() > 0) return f;
    } on FileSystemException {
      // fall through
    }
    return null;
  }

  /// Any local copy of [bookId] regardless of format (epub preferred).
  Future<File?> findLocal(String bookId) async {
    try {
      final dir = await booksDir();
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.startsWith('$bookId.') && !name.endsWith('.part')) {
          if (await e.length() > 0) return e;
        }
      }
    } on FileSystemException {
      // fall through
    }
    return null;
  }

  /// Removes every stored copy of [bookId] (any format) and `.part` leftovers.
  Future<void> delete(String bookId) async {
    try {
      final dir = await booksDir();
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        final name = e.path.split(Platform.pathSeparator).last;
        if (name.startsWith('$bookId.')) {
          try {
            await e.delete();
          } on FileSystemException {
            // best effort
          }
        }
      }
    } on FileSystemException {
      // best effort
    }
  }

  // ── downloading ─────────────────────────────────────────────────────────────

  /// Local file for [book], downloading it first when needed.
  Future<File> ensureLocal(
    Book book, {
    void Function(double? progress)? onProgress,
  }) async {
    final format = _formatOf(book);
    final existing = await localFile(book.id, format);
    if (existing != null) return existing;
    final url = book.readableUrl;
    if (url.isEmpty) {
      // Local-first book (source "local"): the file only exists on the device
      // that imported it.
      if (book.source == 'local' || book.id.startsWith('local_')) {
        throw const MissingLocalFileException();
      }
      throw const DownloadException(message: 'This book has no downloadable file.');
    }
    return downloadBook(
      bookId: book.id,
      url: url,
      format: format,
      onProgress: onProgress,
    );
  }

  /// Downloads [url] to `books/<bookId>.<format>`. Concurrent calls for the
  /// same book share one download. [onProgress] gets 0–1, or null when the
  /// server does not report a size.
  Future<File> downloadBook({
    required String bookId,
    required String url,
    required String format,
    void Function(double? progress)? onProgress,
  }) {
    final key = '$bookId.${_ext(format)}';
    final running = _inFlight[key];
    if (running != null) return running;

    final future = _download(
      key: key,
      bookId: bookId,
      url: url,
      format: _ext(format),
      onProgress: onProgress,
    ).whenComplete(() {
      _inFlight.remove(key);
      _tokens.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  /// Cancels a running download (the `.part` file is removed).
  void cancel(String bookId) {
    for (final entry in _tokens.entries.toList()) {
      if (entry.key.startsWith('$bookId.')) {
        entry.value.cancel('cancelled');
      }
    }
  }

  /// Gutenberg's `…/ebooks/N.epub3.images` links are generated on demand (slow,
  /// sometimes minutes) while the static files under `/cache/epub/` are served
  /// instantly. For those links the fast files are tried first and the original
  /// URL stays as the last fallback.
  static List<String> candidateUrls(String url) {
    final m = RegExp(r'^https?://(?:www\.)?gutenberg\.org/ebooks/(\d+)\.epub')
        .firstMatch(url);
    if (m == null) return [url];
    final id = m.group(1)!;
    return [
      'https://www.gutenberg.org/cache/epub/$id/pg$id-images.epub',
      'https://www.gutenberg.org/cache/epub/$id/pg$id-images-3.epub',
      url,
    ];
  }

  Future<File> _download({
    required String key,
    required String bookId,
    required String url,
    required String format,
    void Function(double? progress)? onProgress,
  }) async {
    final candidates = candidateUrls(url);
    Object? lastError;
    for (var i = 0; i < candidates.length; i++) {
      try {
        return await _downloadOne(
          key: key,
          bookId: bookId,
          url: candidates[i],
          format: format,
          onProgress: onProgress,
        );
      } on NetworkException {
        rethrow; // offline: the other mirrors will not help
      } on DownloadException catch (e) {
        if (e.message == 'Download cancelled.') rethrow;
        lastError = e;
      } on AppException catch (e) {
        lastError = e;
      }
    }
    if (lastError is AppException) throw lastError;
    throw const DownloadException(message: 'Download failed. Please try again.');
  }

  Future<File> _downloadOne({
    required String key,
    required String bookId,
    required String url,
    required String format,
    void Function(double? progress)? onProgress,
  }) async {
    final dir = await booksDir();
    final finalPath = '${dir.path}${Platform.pathSeparator}$key';
    final partFile = File('$finalPath.part');
    final token = CancelToken();
    _tokens[key] = token;

    try {
      if (await partFile.exists()) await partFile.delete();

      final res = await _dio.download(
        url,
        partFile.path,
        cancelToken: token,
        // Inspect the status ourselves; never let Dio throw before we know.
        options: Options(validateStatus: (_) => true),
        onReceiveProgress: (received, total) {
          onProgress?.call(total > 0 ? received / total : null);
        },
      );

      final status = res.statusCode ?? 0;
      if (status != 200) {
        await _safeDelete(partFile);
        if (status == 401 || status == 403) {
          throw DownloadBlockedException(statusCode: status);
        }
        throw DownloadException(
          message: 'Download failed (HTTP $status).',
          statusCode: status,
        );
      }

      if (!await hasValidMagicBytes(partFile, format)) {
        await _safeDelete(partFile);
        throw InvalidFileException(format: format.toUpperCase());
      }

      await partFile.rename(finalPath);
      onProgress?.call(1);
      return File(finalPath);
    } on DioException catch (e) {
      await _safeDelete(partFile);
      if (CancelToken.isCancel(e)) {
        throw const DownloadException(message: 'Download cancelled.');
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          throw const RequestTimeoutException();
        case DioExceptionType.connectionError:
          throw const NetworkException();
        default:
          throw DownloadException(
            message: e.error.toString().contains('SocketException')
                ? 'No internet connection. Please check your network.'
                : 'Download failed. Please try again.',
          );
      }
    } on FileSystemException {
      await _safeDelete(partFile);
      throw const DownloadException(
        message: 'Could not save the file. Is your storage full?',
      );
    } catch (e) {
      await _safeDelete(partFile);
      if (e is AppException) rethrow;
      throw DownloadException(message: 'Download failed: $e');
    }
  }

  // ── imported / local files ──────────────────────────────────────────────────

  /// Copies [source] to `books/<bookId>.<format>` (via `.part`, magic-byte
  /// checked, atomic rename). Used after an upload so the book is readable
  /// offline immediately.
  Future<File> importLocalCopy({
    required String bookId,
    required File source,
    required String format,
  }) async {
    final ext = _ext(format);
    final dir = await booksDir();
    final finalPath = '${dir.path}${Platform.pathSeparator}$bookId.$ext';
    final part = File('$finalPath.part');
    try {
      if (await part.exists()) await part.delete();
      await source.copy(part.path);
      if (!await hasValidMagicBytes(part, ext)) {
        throw InvalidFileException(format: ext.toUpperCase());
      }
      await part.rename(finalPath);
      return File(finalPath);
    } on FileSystemException {
      await _safeDelete(part);
      throw const DownloadException(
        message: 'Could not save the file. Is your storage full?',
      );
    } catch (_) {
      await _safeDelete(part);
      rethrow;
    }
  }

  /// Permanent copy for books that are *not* in the account
  /// (`books/local/<timestamp>_<safe name>`).
  Future<File> saveLocalOnly({
    required File source,
    required String name,
    required String format,
  }) async {
    final dir = await booksDir();
    final localDir =
        Directory('${dir.path}${Platform.pathSeparator}local');
    if (!await localDir.exists()) await localDir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final dest = File(
      '${localDir.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}_$safe',
    );
    try {
      await source.copy(dest.path);
    } on FileSystemException {
      throw const DownloadException(
        message: 'Could not save the file. Is your storage full?',
      );
    }
    return dest;
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  static String _ext(String format) => storageExtension(format);

  static String _formatOf(Book book) => book.format.isEmpty ? 'epub' : book.format;

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // ignore
    }
  }

  /// `%PDF-` for PDF; `PK` (zip) for EPUB. Public so Phase 7 reuses it for
  /// picked files.
  static Future<bool> hasValidMagicBytes(File file, String format) async {
    final f = normalizeFormat(format);
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final head = await raf.read(5);
      if (f == 'pdf') {
        return head.length >= 5 &&
            head[0] == 0x25 && // %
            head[1] == 0x50 && // P
            head[2] == 0x44 && // D
            head[3] == 0x46 && // F
            head[4] == 0x2D; // -
      }
      if (kZipFormats.contains(f)) {
        return head.length >= 2 && head[0] == 0x50 && head[1] == 0x4B; // PK
      }
      return head.isNotEmpty; // text, html, csv, mobi, doc… : just not empty
    } on FileSystemException {
      return false;
    } finally {
      await raf?.close();
    }
  }
}
