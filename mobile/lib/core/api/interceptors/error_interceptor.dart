import 'package:dio/dio.dart';

import '../../errors/app_exception.dart';

/// Maps raw [DioException]s to typed [AppException]s (stored in `error`).
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // reject(), not throw: throwing would re-wrap and hide our mapped error.
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: err.error is AppException ? err.error : _map(err),
      ),
    );
  }

  AppException _map(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        return _mapStatus(err.response);
      case DioExceptionType.cancel:
        return const UnknownException(message: 'Request was cancelled.');
      case DioExceptionType.badCertificate:
        return const UnknownException(message: 'SSL certificate error.');
      case DioExceptionType.unknown:
        if (err.error.toString().contains('SocketException')) {
          return const NetworkException();
        }
        return const UnknownException();
    }
  }

  AppException _mapStatus(Response<dynamic>? response) {
    if (response == null) return const UnknownException();

    final code = response.statusCode;
    final data = response.data;
    final message = _message(data);

    return switch (code) {
      400 => ServerException(message: message ?? 'Bad request.', statusCode: 400),
      401 => UnauthorizedException(
          message: message ?? 'Session expired. Please log in again.',
        ),
      403 => ForbiddenException(
          message:
              message ?? 'You do not have permission to perform this action.',
        ),
      404 => NotFoundException(message: message ?? 'Resource not found.'),
      422 => ValidationException(
          message: message ?? 'Validation failed.',
          errors: _validationErrors(data),
        ),
      429 => RateLimitException(
          message: message ?? 'Too many requests. Please slow down.',
        ),
      500 || 502 || 503 || 504 => ServerException(
          message: 'Server error. Please try again later.',
          statusCode: code,
        ),
      _ => ServerException(
          message: message ?? 'Something went wrong.',
          statusCode: code,
        ),
    };
  }

  String? _message(dynamic data) {
    if (data is Map) {
      final m = data['message'] ?? data['error'];
      if (m is String && m.isNotEmpty) return m;
    }
    return null;
  }

  Map<String, List<String>>? _validationErrors(dynamic data) {
    if (data is! Map) return null;
    final errors = data['errors'];
    if (errors is! Map) return null;
    return errors.map((key, value) {
      final msgs = switch (value) {
        List<dynamic> list => list.map((e) => e.toString()).toList(),
        String s => <String>[s],
        _ => <String>[],
      };
      return MapEntry(key.toString(), msgs);
    });
  }
}
