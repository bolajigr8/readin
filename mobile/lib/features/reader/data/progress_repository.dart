import '../../../core/api/api_client.dart';
import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_result.dart';
import 'reader_models.dart';

/// `GET` / `PUT /progress/:bookId`.
class ProgressRepository {
  ProgressRepository(this._api);

  final ApiClient _api;

  /// `null` data = the user has not started the book (server: `{progress:null}`).
  Future<ApiResult<SavedProgress?>> get(String bookId) => _api.get<SavedProgress?>(
        ApiEndpoints.progress(bookId),
        parser: (d) {
          final p = d is Map ? d['progress'] : null;
          return p is Map ? SavedProgress.fromJson(Map<String, dynamic>.from(p)) : null;
        },
      );

  Future<ApiResult<void>> save(
    String bookId,
    ProgressPayload payload,
    int readingTimeDeltaSeconds,
  ) =>
      _api.put<void>(
        ApiEndpoints.progress(bookId),
        data: payload.toJson(readingTimeDeltaSeconds),
        parser: (_) {},
      );
}
