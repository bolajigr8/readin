import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/doc_syncer.dart';
import '../auth/providers/auth_providers.dart';
import '../library/data/models/book.dart';
import '../library/providers/library_providers.dart';
import 'shelf_models.dart';

const String _kShelves = '@readin/shelves_v1';

/// Pseudo shelf id of the ★ Favorites filter.
const String kFavoritesFilter = '__favorites__';

class ShelvesNotifier extends StateNotifier<ShelfData> {
  ShelvesNotifier(this._ref)
      : super(ShelfData.decode(_ref.read(storageServiceProvider).readString(_kShelves))) {
    _syncer = DocSyncer(
      api: _ref.read(apiClientProvider),
      storage: _ref.read(storageServiceProvider),
      key: 'shelves',
      readLocal: () => state.encode(),
      isLocalEmpty: () =>
          state.status.isEmpty && state.shelves.isEmpty && state.favorites.isEmpty,
      applyRemote: (json) {
        state = ShelfData.decode(json);
        _ref.read(storageServiceProvider).writeString(_kShelves, json);
      },
      merge: (a, b) => mergeShelfData(ShelfData.decode(a), ShelfData.decode(b)).encode(),
      enabled: () => _ref.read(authProvider).isAuthenticated,
    );
  }

  final Ref _ref;
  late final DocSyncer _syncer;

  @override
  void dispose() {
    _syncer.dispose();
    super.dispose();
  }

  Future<void> pull() => _syncer.pull();

  /// Sign-out: the next account must not see (or upload) this one's data.
  void clearLocal() {
    state = const ShelfData();
    _ref.read(storageServiceProvider).writeString(_kShelves, '');
    _ref.read(storageServiceProvider).writeInt('@readin/sync_v_shelves', 0);
  }

  void _save(ShelfData d) {
    state = d;
    _ref.read(storageServiceProvider).writeString(_kShelves, d.encode());
    _syncer.markChanged();
  }

  void setStatus(Book b, ReadStatus s) {
    final status = {...state.status};
    final fin = {...state.finishedAt};
    if (s == ReadStatus.none) {
      status.remove(b.id);
    } else {
      status[b.id] = s;
    }
    if (s == ReadStatus.finished) {
      fin[b.id] = DateTime.now();
    } else {
      fin.remove(b.id);
    }
    _save(state.copyWith(status: status, finishedAt: fin));
  }

  Shelf createShelf(String name) {
    final shelf = Shelf(id: DateTime.now().microsecondsSinceEpoch.toString(), name: name.trim());
    _save(state.copyWith(shelves: [...state.shelves, shelf]));
    return shelf;
  }

  void renameShelf(String id, String name) => _save(state.copyWith(
        shelves: [for (final s in state.shelves) s.id == id ? s.copyWith(name: name.trim()) : s],
      ));

  void deleteShelf(String id) =>
      _save(state.copyWith(shelves: state.shelves.where((s) => s.id != id).toList()));

  void toggleOnShelf(String shelfId, String bookId) => _save(state.copyWith(
        shelves: [
          for (final s in state.shelves)
            if (s.id == shelfId)
              s.copyWith(
                bookIds: s.bookIds.contains(bookId)
                    ? (s.bookIds.toSet()..remove(bookId))
                    : {...s.bookIds, bookId},
              )
            else
              s,
        ],
      ));

  void toggleFavorite(String bookId) {
    final f = {...state.favorites};
    f.contains(bookId) ? f.remove(bookId) : f.add(bookId);
    _save(state.copyWith(favorites: f));
  }

  void setYearlyGoal(int goal) => _save(state.copyWith(yearlyGoal: goal.clamp(1, 365).toInt()));
}

final shelvesProvider =
    StateNotifierProvider<ShelvesNotifier, ShelfData>((ref) => ShelvesNotifier(ref));

/// Library filter chip: everything / a status / one custom shelf.
class ShelfFilter {
  const ShelfFilter.all()
      : status = null,
        shelfId = null;
  const ShelfFilter.status(ReadStatus this.status) : shelfId = null;
  const ShelfFilter.shelf(String this.shelfId) : status = null;
  const ShelfFilter.favorites()
      : status = null,
        shelfId = kFavoritesFilter;

  final ReadStatus? status;
  final String? shelfId;

  bool get isAll => status == null && shelfId == null;

  @override
  bool operator ==(Object other) =>
      other is ShelfFilter && other.status == status && other.shelfId == shelfId;

  @override
  int get hashCode => Object.hash(status, shelfId);
}

final shelfFilterProvider = StateProvider<ShelfFilter>((ref) => const ShelfFilter.all());

List<Book> applyShelfFilter(List<Book> books, ShelfData d, ShelfFilter f) {
  if (f.isAll) return books;
  if (f.status != null) return books.where((b) => effectiveStatus(b, d) == f.status).toList();
  if (f.shelfId == kFavoritesFilter) return books.where((b) => d.favorites.contains(b.id)).toList();
  final shelf = d.shelves.where((s) => s.id == f.shelfId).firstOrNull;
  if (shelf == null) return books;
  return books.where((b) => shelf.bookIds.contains(b.id)).toList();
}

/// Books finished this year / yearly goal.
final challengeProvider = Provider.autoDispose<({int goal, int finished, int year})>((ref) {
  final data = ref.watch(shelvesProvider);
  final books = ref.watch(libraryProvider).valueOrNull?.books ?? const <Book>[];
  final year = DateTime.now().year;
  return (goal: data.yearlyGoal, finished: finishedInYear(books, data, year), year: year);
});
