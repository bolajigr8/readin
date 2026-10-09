import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Debug-only request log. Never logs headers/bodies (tokens, passwords).
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) debugPrint('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint(
        '✗ ${err.response?.statusCode ?? err.type.name} '
        '${err.requestOptions.method} ${err.requestOptions.uri}',
      );
    }
    handler.next(err);
  }
}
