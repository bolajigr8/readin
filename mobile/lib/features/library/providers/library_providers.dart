import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/datasources/library_remote_datasource.dart';
import '../data/models/book.dart';
import '../data/repositories/library_repository.dart';
import '../data/local_import_service.dart';
import '../data/local_library_store.dart';
import '../utils/library_logic.dart';
import '../../shelves/shelf_providers.dart';
import 'download_providers.dart';

final libraryRepositoryProvider = Provider<LibraryRepository>(
  (ref) => LibraryRepository(
    LibraryRemoteDataSource(ref.watch(apiClientProvider)),
  ),
);

final localLibraryStoreProvider = Provider<LocalLibraryStore>((ref) => LocalLibraryStore());

final localImportServiceProvider = Provider<LocalImportService>(
  (ref) => LocalImportService(
    downloads: ref.watch(downloadServiceProvider),
    store: ref.watch(localLibraryStoreProvider),
    repo: ref.watch(libraryRepositoryProvider),
    userId: () => ref.read(authProvider).user?.id,
  ),
);

/// The user's library — **offline-first**:
///
/// 1. the cached library (last server answer) + books imported on this phone
///    are shown IMMEDIATELY, even if the server is asleep or the phone offline;
/// 2. in the background the server is asked again; pending local books are
///    registered; the list updates when the answer arrives;
/// 3. a failed refresh never wipes what is on screen.
///
/// Kept for 2 minutes after the last listener leaves; per user.
class LibraryNotifier extends AutoDisposeAsyncNotifier<LibraryResponse> {
  bool _disposed = false;
  String? _userId;

  @override
  Future<LibraryResponse> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final userId = ref.watch(authProvider.select((s) => s.user?.id));
    _userId = userId;

    final link = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 2), link.close);
    ref.onDispose(timer.cancel);

    if (userId == null) return LibraryResponse.empty;

    final store = ref.read(localLibraryStoreProvider);
    final cached = await store.readCache(userId);
    final pending = await store.readPending(userId);

    if (cached != null) {
      // Instant paint from the cache, refresh quietly afterwards.
      Future<void>(() => refresh(silent: true));
      return mergeLibrary(cached, pending);
    }
    if (pending.isNotEmpty) {
      Future<void>(() => refresh(silent: true));
      return mergeLibrary(LibraryResponse.empty, pending);
    }
    // First launch: nothing local yet → wait for the server.
    return _fetchFresh(userId, store);
  }

  Future<LibraryResponse> _fetchFresh(String userId, LocalLibraryStore store) async {
    // Register books imported while offline first, so they show up as normal.
    try {
      await ref.read(localImportServiceProvider).syncPending();
    } catch (_) {}
    final res = await ref.read(libraryRepositoryProvider).fetchAll();
    final fresh = res.dataOrNull;
    if (fresh == null) throw res.exceptionOrNull!;
    await store.writeCache(userId, fresh);
    final pending = await store.readPending(userId);
    return mergeLibrary(fresh, pending);
  }

  /// Re-fetches from the server. With [silent] a failure keeps the current list.
  Future<void> refresh({bool silent = false}) async {
    final userId = _userId ?? ref.read(authProvider).user?.id;
    if (userId == null || _disposed) return;
    final store = ref.read(localLibraryStoreProvider);
    try {
      final merged = await _fetchFresh(userId, store);
      if (!_disposed) state = AsyncData(merged);
    } catch (e, st) {
      if (_disposed) return;
      // Offline / server asleep: keep showing what we have.
      if (!state.hasValue) state = AsyncError(e, st);
      if (!silent && state.hasValue) rethrow;
    }
  }
}

/// Server books + pending local books (pending first, no duplicates).
LibraryResponse mergeLibrary(LibraryResponse server, List<Book> pending) {
  final ids = {for (final b in server.books) b.id};
  final prints = {for (final b in server.books) if (b.fingerprint.isNotEmpty) b.fingerprint};
  final extra = pending
      .where((p) => !ids.contains(p.id) && !prints.contains(p.fingerprint))
      .toList();
  return LibraryResponse(
    books: [...extra, ...server.books],
    meta: LibraryMeta(
      total: server.meta.total + extra.length,
      page: server.meta.page,
      limit: server.meta.limit,
      totalPages: server.meta.totalPages,
      limitReached: server.meta.limitReached,
    ),
  );
}

final libraryProvider =
    AsyncNotifierProvider.autoDispose<LibraryNotifier, LibraryResponse>(LibraryNotifier.new);

/// Forces a re-fetch and waits for it (pull-to-refresh).
Future<void> refreshLibrary(WidgetRef ref) async {
  try {
    await ref.read(libraryProvider.notifier).refresh();
  } catch (_) {
    // The screens keep showing the cached list.
  }
}

/// Top 3 in-progress books (see [selectContinueReading]).
final continueReadingProvider = Provider.autoDispose<List<Book>>((ref) {
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  return selectContinueReading(books);
});

// ── Library tab UI state ─────────────────────────────────────────────────────

final librarySearchProvider = StateProvider<String>((ref) => '');
final librarySortProvider = StateProvider<SortKey>((ref) => SortKey.recent);

/// 1 = list, 2 = grid.
final libraryColumnsProvider = StateProvider<int>((ref) => 2);

/// Ready books → filtered by search → sorted.
final processedBooksProvider = Provider.autoDispose<List<Book>>((ref) {
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  final query = ref.watch(librarySearchProvider);
  final sort = ref.watch(librarySortProvider);
  final shelves = ref.watch(shelvesProvider);
  final filter = ref.watch(shelfFilterProvider);
  return sortBooks(filterBooks(applyShelfFilter(books, shelves, filter), query), sort);
});

/// `await ref.read(deleteBookProvider)(book)` → removes the book on the
/// server, deletes the local file and refreshes the library.
final deleteBookProvider = Provider<Future<ApiResult<void>> Function(Book)>(
  (ref) => (Book book) async {
    // Not on the server yet → nothing to delete remotely.
    if (book.id.startsWith('local_')) {
      final uid = ref.read(authProvider).user?.id;
      if (uid != null) await ref.read(localLibraryStoreProvider).removePending(uid, book.id);
      await ref.read(downloadServiceProvider).delete(book.id);
      ref.invalidate(bookDownloadProvider(book.id));
      ref.invalidate(libraryProvider);
      return const Success<void>(null);
    }
    final res = await ref.read(libraryRepositoryProvider).deleteBook(book.id);
    if (res.isSuccess) {
      await ref.read(downloadServiceProvider).delete(book.id);
      ref.invalidate(bookDownloadProvider(book.id));
      ref.invalidate(libraryProvider);
    }
    return res;
  },
);

/// Gutenberg ids (as strings) of books already in the library — drives the
/// green "in library" badges on Discover.
final libraryGutenbergIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  return {
    for (final b in books)
      if (b.gutenbergId != null) b.gutenbergId!,
  };
});

/// The library entry for a Gutenberg id, if any.
final libraryBookByGutenbergIdProvider =
    Provider.autoDispose.family<Book?, String>((ref, gid) {
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  for (final b in books) {
    if (b.gutenbergId == gid) return b;
  }
  return null;
});
