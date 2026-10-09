import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/annotation_models.dart';
import '../data/annotations_repository.dart';

final annotationsRepositoryProvider = Provider<AnnotationsRepository>(
  (ref) => AnnotationsRepository(ref.watch(apiClientProvider)),
);

final bookmarksRepositoryProvider = Provider<BookmarksRepository>(
  (ref) => BookmarksRepository(ref.watch(apiClientProvider)),
);

class AnnotationsState {
  const AnnotationsState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });

  final List<Annotation> items;
  final bool isLoading;
  final AppException? error;

  AnnotationsState copyWith({
    List<Annotation>? items,
    bool? isLoading,
    AppException? error,
    bool clearError = false,
  }) =>
      AnnotationsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Annotations of one book. `bookId == ''` (local files) → inert, no network.
class AnnotationsNotifier extends StateNotifier<AnnotationsState> {
  AnnotationsNotifier(this._repo, this.bookId)
      : super(AnnotationsState(isLoading: bookId.isNotEmpty)) {
    if (bookId.isNotEmpty) load();
  }

  final AnnotationsRepository _repo;
  final String bookId;

  Future<void> load() async {
    if (bookId.isEmpty) return;
    state = state.copyWith(isLoading: true, clearError: true);
    final res = await _repo.list(bookId);
    if (!mounted) return;
    res.when(
      success: (list) => state = AnnotationsState(items: list, isLoading: false),
      failure: (e) => state = state.copyWith(isLoading: false, error: e),
    );
  }

  /// Returns the created annotation, or the failure (403 = free limit).
  Future<ApiResult<Annotation>> create(NewAnnotation a) async {
    final res = await _repo.create(bookId, a);
    if (mounted) {
      res.onSuccess((created) {
        state = state.copyWith(items: [...state.items, created]);
      });
    }
    return res;
  }

  Future<ApiResult<Annotation>> updateNote(String id, String note) async {
    final res = await _repo.update(id, note: note);
    if (mounted) {
      res.onSuccess((u) {
        state = state.copyWith(
          items: [for (final a in state.items) a.id == id ? u : a],
        );
      });
    }
    return res;
  }

  /// Optimistic: the row disappears immediately; restored if the server fails.
  Future<ApiResult<void>> delete(String id) async {
    final before = state.items;
    state = state.copyWith(items: before.where((a) => a.id != id).toList());
    final res = await _repo.delete(id);
    if (mounted && res.isFailure) state = state.copyWith(items: before);
    return res;
  }
}

final annotationsProvider = StateNotifierProvider.autoDispose
    .family<AnnotationsNotifier, AnnotationsState, String>(
  (ref, bookId) => AnnotationsNotifier(ref.watch(annotationsRepositoryProvider), bookId),
);

class BookmarksState {
  const BookmarksState({this.items = const [], this.isLoading = true});

  final List<Bookmark> items;
  final bool isLoading;

  Bookmark? byCfi(String? cfi) {
    if (cfi == null || cfi.isEmpty) return null;
    for (final b in items) {
      if (b.cfi == cfi) return b;
    }
    return null;
  }
}

class BookmarksNotifier extends StateNotifier<BookmarksState> {
  BookmarksNotifier(this._repo, this.bookId)
      : super(BookmarksState(isLoading: bookId.isNotEmpty)) {
    if (bookId.isNotEmpty) load();
  }

  final BookmarksRepository _repo;
  final String bookId;

  Future<void> load() async {
    if (bookId.isEmpty) return;
    final res = await _repo.list(bookId);
    if (!mounted) return;
    state = BookmarksState(items: res.dataOrNull ?? state.items, isLoading: false);
  }

  Future<ApiResult<Bookmark>> add(NewBookmark b) async {
    final res = await _repo.create(bookId, b);
    if (mounted) {
      res.onSuccess((created) {
        // The server is idempotent per cfi: never show a duplicate row.
        final others = state.items.where((x) => x.id != created.id && x.cfi != created.cfi);
        state = BookmarksState(items: [...others, created], isLoading: false);
      });
    }
    return res;
  }

  Future<ApiResult<void>> remove(String id) async {
    final before = state.items;
    state = BookmarksState(
      items: before.where((b) => b.id != id).toList(),
      isLoading: false,
    );
    final res = await _repo.delete(id);
    if (mounted && res.isFailure) state = BookmarksState(items: before, isLoading: false);
    return res;
  }
}

final bookmarksProvider = StateNotifierProvider.autoDispose
    .family<BookmarksNotifier, BookmarksState, String>(
  (ref, bookId) => BookmarksNotifier(ref.watch(bookmarksRepositoryProvider), bookId),
);
