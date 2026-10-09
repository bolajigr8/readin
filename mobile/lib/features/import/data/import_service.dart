import 'dart:io';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_result.dart';
import '../../library/data/services/download_service.dart';
import 'import_models.dart';

/// Upload + local-copy logic for importing a book from the phone.
class ImportService {
  ImportService({required ApiClient api, required DownloadService downloads})
      : _api = api,
        _downloads = downloads;

  final ApiClient _api;
  final DownloadService _downloads;

  /// Content check before anything leaves the phone: `%PDF-` / `PK` — so a
  /// renamed `.txt → .epub` is rejected with a clear message.
  Future<void> verify(PickedBook book) async {
    final ok = await DownloadService.hasValidMagicBytes(File(book.path), book.ext);
    if (!ok) {
      throw ImportException(
        'This file does not look like a valid ${book.ext.toUpperCase()}. It may be corrupted.',
      );
    }
  }

  /// `POST /files/upload` (multipart field `file`, correct content type,
  /// original file name so the server can derive the title).
  Future<ApiResult<UploadedBook>> upload(
    PickedBook book, {
    void Function(double progress)? onProgress,
  }) {
    return _api.postMultipart<UploadedBook>(
      ApiEndpoints.filesUpload,
      file: File(book.path),
      fileKey: 'file',
      filename: book.name,
      contentType: book.contentType,
      parser: (d) => UploadedBook.fromJson(Map<String, dynamic>.from(d as Map)),
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
  }

  /// Keeps the picked file as `books/<bookId>.<ext>` so the new book opens
  /// instantly and offline (no re-download). Best effort: failures are
  /// swallowed — the reader will simply download it later.
  Future<File?> storeLocalCopy(String bookId, PickedBook book) async {
    try {
      return await _downloads.importLocalCopy(
        bookId: bookId,
        source: File(book.path),
        format: book.ext,
      );
    } catch (_) {
      return null;
    }
  }

  /// "Read without saving": copies the file to permanent app storage and
  /// returns the request the reader opens (`bookId = 'local'`).
  Future<LocalReadRequest> saveLocalOnly(PickedBook book) async {
    final file = await _downloads.saveLocalOnly(
      source: File(book.path),
      name: book.name,
      format: book.ext,
    );
    return LocalReadRequest(path: file.path, title: book.title, format: book.ext);
  }
}
