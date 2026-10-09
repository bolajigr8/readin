import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';
import '../data/gutenberg_models.dart';
import '../data/gutendex_datasource.dart';

final gutendexDataSourceProvider =
    Provider<GutendexDataSource>((ref) => GutendexDataSource());

// ── Paged feed ───────────────────────────────────────────────────────────────

enum DiscoverKind { popular, category, search }

/// Value-equal key of a feed (used as the provider family argument).
class DiscoverQuery {
  const DiscoverQuery(this.kind, [this.value = '']);

  const DiscoverQuery.popular() : this(DiscoverKind.popular);

  final DiscoverKind kind;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is DiscoverQuery && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);
}

class DiscoverFeedState {
  const DiscoverFeedState({
    this.books = const [],
    this.count = 0,
    this.nextPage,
    this.isLoading = true,
    this.isFetchingNext = false,
    this.error,
    this.nextError,
  });

  final List<GutenbergBook> books;

  /// Total results reported by Gutendex.
  final int count;

  /// Next page number, or null when exhausted.
  final int? nextPage;

  /// First page is loading (no data yet).
  final bool isLoading;
  final bool isFetchingNext;

  /// First-page error (nothing to show).
  final AppException? error;

  /// Error while loading a later page (list stays).
  final AppException? nextError;

  bool get hasNext => nextPage != null;
  bool get hasData => books.isNotEmpty || (!isLoading && error == null);

  DiscoverFeedState copyWith({
    List<GutenbergBook>? books,
    int? count,
    int? nextPage,
    bool clearNext = false,
    bool? isLoading,
    bool? isFetchingNext,
    AppException? error,
    bool clearError = false,
    AppException? nextError,
    bool clearNextError = false,
  }) =>
      DiscoverFeedState(
        books: books ?? this.books,
        count: count ?? this.count,
        nextPage: clearNext ? null : (nextPage ?? this.nextPage),
        isLoading: isLoading ?? this.isLoading,
        isFetchingNext: isFetchingNext ?? this.isFetchingNext,
        error: clearError ? null : (error ?? this.error),
        nextError: clearNextError ? null : (nextError ?? this.nextError),
      );
}

class DiscoverFeedNotifier extends StateNotifier<DiscoverFeedState> {
  DiscoverFeedNotifier(this._ds, this.query) : super(const DiscoverFeedState()) {
    loadFirst();
  }

  final GutendexDataSource _ds;
  final DiscoverQuery query;

  Future<ApiResult<GutenbergPage>> _fetch(int page) => switch (query.kind) {
        DiscoverKind.popular => _ds.popular(page: page),
        DiscoverKind.category => _ds.byTopic(query.value, page: page),
        DiscoverKind.search => _ds.search(query.value, page: page),
      };

  Future<void> loadFirst() async {
    state = const DiscoverFeedState(isLoading: true);
    final res = await _fetch(1);
    if (!mounted) return;
    res.when(
      success: (p) => state = DiscoverFeedState(
        books: p.results,
        count: p.count,
        nextPage: p.hasNext ? 2 : null,
        isLoading: false,
      ),
      failure: (e) =>
          state = DiscoverFeedState(isLoading: false, error: e),
    );
  }

  /// Pull the next page (no-op while loading / exhausted). After a failure
  /// it only runs again when [retry] is true (the user tapped "Tap to retry"),
  /// otherwise scrolling would hammer the network.
  Future<void> loadMore({bool retry = false}) async {
    final next = state.nextPage;
    if (next == null ||
        state.isFetchingNext ||
        state.isLoading ||
        state.error != null ||
        (state.nextError != null && !retry)) {
      return;
    }
    state = state.copyWith(isFetchingNext: true, clearNextError: true);
    final res = await _fetch(next);
    if (!mounted) return;
    res.when(
      success: (p) {
        // De-duplicate by id (Gutendex pages can overlap while data changes).
        final seen = state.books.map((b) => b.id).toSet();
        final merged = [
          ...state.books,
          ...p.results.where((b) => !seen.contains(b.id)),
        ];
        state = state.copyWith(
          books: merged,
          count: p.count,
          nextPage: p.hasNext ? next + 1 : null,
          clearNext: !p.hasNext,
          isFetchingNext: false,
        );
      },
      failure: (e) =>
          state = state.copyWith(isFetchingNext: false, nextError: e),
    );
  }
}

/// One paged feed per [DiscoverQuery]; kept for 10 min (5 for searches) after
/// the last listener leaves (RN `staleTime`).
final discoverFeedProvider = StateNotifierProvider.autoDispose
    .family<DiscoverFeedNotifier, DiscoverFeedState, DiscoverQuery>((ref, q) {
  final link = ref.keepAlive();
  final timer = Timer(
    Duration(minutes: q.kind == DiscoverKind.search ? 5 : 10),
    link.close,
  );
  ref.onDispose(timer.cancel);
  return DiscoverFeedNotifier(ref.watch(gutendexDataSourceProvider), q);
});

// ── Discover screen UI state ─────────────────────────────────────────────────

/// Debounced (400 ms), trimmed search text. `''` = not searching.
final discoverSearchProvider = StateProvider<String>((ref) => '');

/// Active category id or null.
final discoverCategoryProvider = StateProvider<String?>((ref) => null);

/// Which feed the grid shows right now.
final discoverActiveQueryProvider = Provider<DiscoverQuery>((ref) {
  final q = ref.watch(discoverSearchProvider);
  final cat = ref.watch(discoverCategoryProvider);
  if (q.length >= 2) return DiscoverQuery(DiscoverKind.search, q);
  if (cat != null) return DiscoverQuery(DiscoverKind.category, cat);
  return const DiscoverQuery.popular();
});

// ── Single book ──────────────────────────────────────────────────────────────

/// `GET gutendex/books/:id`, cached 1 h.
final gutenbergBookProvider =
    FutureProvider.autoDispose.family<GutenbergBook, int>((ref, id) async {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(hours: 1), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(gutendexDataSourceProvider).byId(id).unwrap();
});
