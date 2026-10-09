import 'dart:async';

import 'package:dio/dio.dart';

import '../api/api_endpoints.dart';
import 'storage_service.dart';

/// The refresh token was rejected (or missing): the session is over.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
}

/// Token facade + single-flight refresh.
///
/// Many requests can hit a 401 at once; they all await the **same** refresh
/// call, so `/auth/refresh` is only invoked once.
class TokenService {
  TokenService({required StorageService storage, Dio? refreshDio})
      : _storage = storage,
        _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: ApiEndpoints.baseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

  final StorageService _storage;

  /// Plain Dio **without interceptors** (no auth loop).
  final Dio _refreshDio;
  Dio get refreshDio => _refreshDio;

  Future<String?>? _inFlight;

  Future<String?> getAccessToken() => _storage.accessToken;
  Future<String?> getRefreshToken() => _storage.refreshToken;

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.setAccessToken(accessToken);
    await _storage.setRefreshToken(refreshToken);
  }

  Future<void> clearTokens() => _storage.clearSecure();

  /// Refreshes the access token once for all concurrent callers.
  ///
  /// Returns the new access token. Throws [SessionExpiredException] when the
  /// refresh token is missing/rejected (4xx). Other failures (network, 5xx)
  /// are rethrown as-is and must NOT log the user out.
  Future<String> refreshAccessToken() async {
    final existing = _inFlight;
    if (existing != null) {
      final t = await existing;
      if (t == null) throw const SessionExpiredException();
      return t;
    }

    final completer = Completer<String?>();
    _inFlight = completer.future;
    // Attach a listener up-front so a failure with no waiters is not reported
    // as an unhandled error.
    unawaited(completer.future.then<void>((_) {}, onError: (Object _) {}));
    try {
      final token = await _doRefresh();
      completer.complete(token);
      return token;
    } on SessionExpiredException {
      completer.complete(null);
      rethrow;
    } catch (e) {
      // Let waiters see a non-session failure as a failed refresh too, but
      // without logging out (they get `null` only for expired sessions).
      completer.completeError(e);
      rethrow;
    } finally {
      _inFlight = null;
    }
  }

  Future<String> _doRefresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null || refresh.isEmpty) {
      throw const SessionExpiredException();
    }

    try {
      final res = await _refreshDio.post<dynamic>(
        ApiEndpoints.refresh,
        data: <String, dynamic>{'refreshToken': refresh},
      );
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final token = data is Map ? data['accessToken'] : null;
      if (token is! String || token.isEmpty) {
        throw const SessionExpiredException();
      }
      await _storage.setAccessToken(token);
      return token;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != null && code >= 400 && code < 500) {
        throw const SessionExpiredException();
      }
      rethrow;
    }
  }
}
