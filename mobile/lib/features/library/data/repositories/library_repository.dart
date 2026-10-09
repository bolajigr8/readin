import '../../../../core/api/api_result.dart';
import '../datasources/library_remote_datasource.dart';
export '../datasources/library_remote_datasource.dart' show RegisteredBook;
import '../models/book.dart';

class LibraryRepository {
  LibraryRepository(this._remote);

  final LibraryRemoteDataSource _remote;

  /// Max pages fetched (50 books each) — a hard stop against a runaway loop.
  static const int _maxPages = 20;

  /// Fetches **all** pages (the server caps `limit` at 50) and returns them as
  /// one response. `meta` is the first page's meta (total / limitReached).
  Future<ApiResult<LibraryResponse>> fetchAll() async {
    final first = await _remote.getLibraryPage(page: 1);
    final firstData = first.dataOrNull;
    if (firstData == null) return first;

    final books = <Book>[...firstData.books];
    final totalPages = firstData.meta.totalPages;

    for (var page = 2; page <= totalPages && page <= _maxPages; page++) {
      final next = await _remote.getLibraryPage(page: page);
      final data = next.dataOrNull;
      if (data == null) return Failure(next.exceptionOrNull!);
      books.addAll(data.books);
    }
    return Success(LibraryResponse(books: books, meta: firstData.meta));
  }

  Future<ApiResult<BookDetail>> getBook(String id) => _remote.getBook(id);

  Future<ApiResult<Book>> addDiscover(Map<String, dynamic> body) =>
      _remote.addDiscover(body);

  Future<ApiResult<RegisteredBook>> registerLocal(Map<String, dynamic> body) =>
      _remote.registerLocal(body);

  Future<ApiResult<void>> deleteBook(String id) => _remote.deleteBook(id);
}
