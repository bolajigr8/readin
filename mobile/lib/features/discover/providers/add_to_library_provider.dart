import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';
import '../../library/data/models/book.dart';
import '../../library/providers/library_providers.dart';
import '../data/gutenberg_models.dart';

/// Request body for `POST /library/discover` (see API_CONTRACT).
/// `epubUrl` must be a valid URL — callers check [epubUrl] first.
Map<String, dynamic> discoverBody(GutenbergBook b) {
  final shelf = b.bookshelves.isNotEmpty
      ? b.bookshelves.first.replaceFirst(RegExp(r'^Browsing:\s*'), '')
      : '';
  return {
    'gutenbergId': b.id.toString(),
    'title': b.title,
    // Formatted ("Jane Austen") — RN stored the raw "Austen, Jane".
    'author': authorsLine(b),
    'description': b.subjects.take(3).join('. '),
    'coverUrl': coverUrl(b.formats, b.id),
    'epubUrl': epubUrl(b.formats) ?? '',
    'language': b.languages.isNotEmpty ? b.languages.first : 'en',
    'genre': shelf,
  };
}

/// True while a `POST /library/discover` is in flight (button "Adding...").
class AddToLibraryNotifier extends StateNotifier<bool> {
  AddToLibraryNotifier(this._ref) : super(false);

  final Ref _ref;

  /// Adds [book]; on success the library is refreshed so badges / buttons
  /// update everywhere. Errors are returned (409/403 handled by the caller).
  Future<ApiResult<Book>> add(GutenbergBook book) async {
    if (state) {
      return const Failure(UnknownException(message: 'Already adding this book.'));
    }
    state = true;
    try {
      final res = await _ref.read(libraryRepositoryProvider).addDiscover(discoverBody(book));
      // Even on 409 the book exists server-side: refresh so the UI catches up.
      _ref.invalidate(libraryProvider);
      return res;
    } finally {
      if (mounted) state = false;
    }
  }
}

final addToLibraryProvider =
    StateNotifierProvider.autoDispose<AddToLibraryNotifier, bool>(
  (ref) => AddToLibraryNotifier(ref),
);
