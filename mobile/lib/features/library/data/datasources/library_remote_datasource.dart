import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_result.dart';
import '../models/book.dart';

/// Result of `POST /library/local`.
class RegisteredBook {
  const RegisteredBook(this.book, {this.deduped = false});
  final Book book;

  /// The server already had this file (same fingerprint).
  final bool deduped;
}

class LibraryRemoteDataSource {
  LibraryRemoteDataSource(this._api);

  final ApiClient _api;

  Future<ApiResult<LibraryResponse>> getLibraryPage({
    int page = 1,
    int limit = 50,
  }) =>
      _api.get<LibraryResponse>(
        ApiEndpoints.libraryList,
        queryParameters: {'page': page, 'limit': limit},
        parser: (d) =>
            LibraryResponse.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  Future<ApiResult<BookDetail>> getBook(String id) => _api.get<BookDetail>(
        ApiEndpoints.libraryBook(id),
        parser: (d) => BookDetail.fromJson(Map<String, dynamic>.from(d as Map)),
      );

  /// `POST /library/discover` → `{book}` (201). 409 already added, 403 limit.
  Future<ApiResult<Book>> addDiscover(Map<String, dynamic> body) =>
      _api.post<Book>(
        ApiEndpoints.libraryDiscover,
        data: body,
        parser: (d) {
          final m = Map<String, dynamic>.from(d as Map);
          final b = m['book'];
          return Book.fromJson(
            b is Map ? Map<String, dynamic>.from(b) : m,
          );
        },
      );

  /// `POST /library/local` — registers a book whose FILE stays on the phone.
  Future<ApiResult<RegisteredBook>> registerLocal(Map<String, dynamic> body) =>
      _api.post<RegisteredBook>(
        ApiEndpoints.libraryLocal,
        data: body,
        parser: (d) {
          final m = Map<String, dynamic>.from(d as Map);
          final b = m['book'];
          return RegisteredBook(
            Book.fromJson(Map<String, dynamic>.from(b as Map)),
            deduped: m['deduped'] == true,
          );
        },
      );

  Future<ApiResult<void>> deleteBook(String id) => _api.delete<void>(
        ApiEndpoints.libraryBook(id),
        parser: (_) {},
      );
}
