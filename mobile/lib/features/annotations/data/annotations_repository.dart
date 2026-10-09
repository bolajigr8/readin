import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_result.dart';
import 'annotation_models.dart';

List<T> _list<T>(dynamic data, String key, T Function(Map<String, dynamic>) parse) {
  final raw = data is Map ? data[key] : null;
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((e) => parse(Map<String, dynamic>.from(e)))
      .toList();
}

/// `/annotations` — response shapes are objects (`{annotations:[]}`,
/// `{annotation}`), **not** bare arrays (the RN hooks cast them wrongly).
class AnnotationsRepository {
  AnnotationsRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<List<Annotation>>> list(String bookId) =>
      _api.get<List<Annotation>>(
        ApiEndpoints.annotationsForBook(bookId),
        parser: (d) => _list(d, 'annotations', Annotation.fromJson),
      );

  /// 201 → `{annotation}`; free plan limit → 403 with the server message.
  Future<ApiResult<Annotation>> create(String bookId, NewAnnotation a) =>
      _api.post<Annotation>(
        ApiEndpoints.annotations,
        data: a.toJson(bookId),
        parser: (d) => Annotation.fromJson(
          Map<String, dynamic>.from((d as Map)['annotation'] as Map),
        ),
      );

  Future<ApiResult<Annotation>> update(String id, {String? note, HighlightColor? color}) =>
      _api.put<Annotation>(
        ApiEndpoints.annotation(id),
        data: {
          if (note != null) 'note': note,
          if (color != null) 'color': color.name,
        },
        parser: (d) => Annotation.fromJson(
          Map<String, dynamic>.from((d as Map)['annotation'] as Map),
        ),
      );

  Future<ApiResult<void>> delete(String id) => _api.delete<void>(
        ApiEndpoints.annotation(id),
        parser: (_) {},
      );
}

/// `/bookmarks` — creation is idempotent per (book, cfi) on the server.
class BookmarksRepository {
  BookmarksRepository(this._api);

  final ApiClient _api;

  Future<ApiResult<List<Bookmark>>> list(String bookId) => _api.get<List<Bookmark>>(
        ApiEndpoints.bookmarksForBook(bookId),
        parser: (d) => _list(d, 'bookmarks', Bookmark.fromJson),
      );

  Future<ApiResult<Bookmark>> create(String bookId, NewBookmark b) =>
      _api.post<Bookmark>(
        ApiEndpoints.bookmarks,
        data: b.toJson(bookId),
        parser: (d) => Bookmark.fromJson(
          Map<String, dynamic>.from((d as Map)['bookmark'] as Map),
        ),
      );

  Future<ApiResult<void>> delete(String id) => _api.delete<void>(
        ApiEndpoints.bookmark(id),
        parser: (_) {},
      );
}
