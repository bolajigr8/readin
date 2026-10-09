import 'package:dio/dio.dart';

import '../../services/token_service.dart';

/// Attaches `Authorization: Bearer` and handles 401 like RN `api.ts`:
///
/// * 401 on a non-`/auth/*` request → refresh **once** (shared by all
///   concurrent requests via [TokenService.refreshAccessToken]) → retry once.
/// * If another request already refreshed the token, just retry with it.
/// * Refresh rejected → clear tokens, call [onSessionExpired], surface 401.
/// * Network/5xx during refresh → surface the original error, keep session.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required Dio dio,
    required TokenService tokenService,
    required Future<void> Function() onSessionExpired,
  })  : _dio = dio,
        _tokens = tokenService,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final TokenService _tokens;
  final Future<void> Function() _onSessionExpired;

  static const String retriedKey = 'readin_retried';
  static const String skipAuthKey = 'readin_skip_auth';

  bool _isAuthPath(String path) =>
      path.startsWith('/auth/') || path.contains('/auth/');

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipAuthKey] != true) {
      final token = await _tokens.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final opts = err.requestOptions;

    final shouldRefresh = err.response?.statusCode == 401 &&
        opts.extra[retriedKey] != true &&
        opts.extra[skipAuthKey] != true &&
        !_isAuthPath(opts.path);
    if (!shouldRefresh) return handler.next(err);

    String token;
    try {
      final current = await _tokens.getAccessToken();
      final sent = opts.headers['Authorization'];
      if (current != null && current.isNotEmpty && sent != 'Bearer $current') {
        // Someone else already refreshed while this request was in flight.
        token = current;
      } else {
        token = await _tokens.refreshAccessToken();
      }
    } on SessionExpiredException {
      await _tokens.clearTokens();
      await _onSessionExpired();
      return handler.next(err);
    } catch (_) {
      // Offline / server down during refresh: keep the session.
      return handler.next(err);
    }

    try {
      opts.headers['Authorization'] = 'Bearer $token';
      opts.extra[retriedKey] = true;
      final data = opts.data;
      if (data is FormData && data.isFinalized) {
        // A multipart body can only be streamed once; rebuild it.
        opts.data = data.clone();
      }
      final response = await _dio.fetch<dynamic>(opts);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }
}
