import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/models/book.dart';
import '../data/services/download_service.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

enum DownloadStatus { idle, downloading, done, error }

class BookDownloadState {
  const BookDownloadState({
    this.status = DownloadStatus.idle,
    this.progress,
    this.error,
    this.path,
  });

  final DownloadStatus status;

  /// 0–1 while downloading; null = unknown size.
  final double? progress;
  final String? error;

  /// Local file path when [status] is [DownloadStatus.done].
  final String? path;

  bool get isDownloaded => status == DownloadStatus.done;
  bool get isDownloading => status == DownloadStatus.downloading;
}

/// Per-book download state. Starts by checking whether a local copy already
/// exists, so "Download for offline" is hidden for books that are on disk.
class BookDownloadNotifier extends StateNotifier<BookDownloadState> {
  BookDownloadNotifier(this._service, this._bookId)
      : super(const BookDownloadState()) {
    _checkLocal();
  }

  final DownloadService _service;
  final String _bookId;

  Future<void> _checkLocal() async {
    final f = await _service.findLocal(_bookId);
    if (!mounted || f == null || state.isDownloading) return;
    state = BookDownloadState(status: DownloadStatus.done, path: f.path);
  }

  /// Re-check disk (after import copy / delete).
  Future<void> refresh() async {
    final f = await _service.findLocal(_bookId);
    if (!mounted) return;
    state = f == null
        ? const BookDownloadState()
        : BookDownloadState(status: DownloadStatus.done, path: f.path);
  }

  /// Downloads [book]. Returns the file, or null on failure (see [state]).
  Future<File?> start(Book book) async {
    if (state.isDownloading) return null;
    state = const BookDownloadState(status: DownloadStatus.downloading, progress: 0);
    try {
      final file = await _service.ensureLocal(
        book,
        onProgress: (p) {
          if (mounted) {
            state = BookDownloadState(
              status: DownloadStatus.downloading,
              progress: p,
            );
          }
        },
      );
      if (mounted) {
        state = BookDownloadState(status: DownloadStatus.done, path: file.path);
      }
      return file;
    } on AppException catch (e) {
      if (mounted) {
        state = BookDownloadState(status: DownloadStatus.error, error: e.message);
      }
      return null;
    } catch (e) {
      if (mounted) {
        state = const BookDownloadState(
          status: DownloadStatus.error,
          error: 'Download failed. Please try again.',
        );
      }
      return null;
    }
  }

  void cancel() => _service.cancel(_bookId);
}

/// `ref.watch(bookDownloadProvider(book.id))`.
final bookDownloadProvider = StateNotifierProvider.family<
    BookDownloadNotifier, BookDownloadState, String>(
  (ref, bookId) =>
      BookDownloadNotifier(ref.watch(downloadServiceProvider), bookId),
);

/// Convenience used by "auto-download after add".
bool autoDownloadEnabled(WidgetRef ref) =>
    ref.read(storageServiceProvider).autoDownloadEpub;
