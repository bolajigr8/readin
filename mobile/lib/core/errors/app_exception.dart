/// Typed errors used across the app. Every `ApiResult.Failure` carries one.
abstract class AppException implements Exception {
  const AppException({required this.message, this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Session expired. Please log in again.',
    super.statusCode = 401,
  });
}

class ForbiddenException extends AppException {
  const ForbiddenException({
    super.message = 'You do not have permission to perform this action.',
    super.statusCode = 403,
  });
}

class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'The requested resource was not found.',
    super.statusCode = 404,
  });
}

class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    this.errors,
    super.statusCode = 422,
  });

  final Map<String, List<String>>? errors;
}

class RateLimitException extends AppException {
  const RateLimitException({
    super.message = 'Too many requests. Please slow down.',
    super.statusCode = 429,
  });
}

class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection. Please check your network.',
  });
}

/// Named `RequestTimeoutException` to avoid clashing with `dart:async`.
class RequestTimeoutException extends AppException {
  const RequestTimeoutException({
    super.message = 'Request timed out. Please try again.',
  });
}

class CacheException extends AppException {
  const CacheException({super.message = 'Something went wrong locally.'});
}

class UnknownException extends AppException {
  const UnknownException({
    super.message = 'An unexpected error occurred. Please try again.',
  });
}
