import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../services/token_service.dart';
import 'api_endpoints.dart';
import 'api_result.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/error_interceptor.dart';
import 'interceptors/logging_interceptor.dart';

/// Maps the server's `data` field to a typed value.
typedef DataParser<T> = T Function(dynamic data);

/// Dio wrapper. Every call returns `ApiResult<T>`, where T is built from the
/// envelope's `data` field (`{success, message, data}`) by [parser].
class ApiClient {
  ApiClient({
    required TokenService tokenService,
    required Future<void> Function() onSessionExpired,
    HttpClientAdapter? adapter,
    String? baseUrl,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    if (adapter != null) _dio.httpClientAdapter = adapter;

    _dio.interceptors.addAll([
      LoggingInterceptor(),
      AuthInterceptor(
        dio: _dio,
        tokenService: tokenService,
        onSessionExpired: onSessionExpired,
      ),
      ErrorInterceptor(),
    ]);
  }

  late final Dio _dio;

  /// Exposed for tests/adapters only.
  Dio get dio => _dio;

  static T _identity<T>(dynamic d) => d as T;

  Future<ApiResult<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    DataParser<T>? parser,
    Options? options,
  }) =>
      _run<T>(
        () => _dio.get<dynamic>(
          path,
          queryParameters: queryParameters,
          options: options,
        ),
        parser,
      );

  Future<ApiResult<T>> post<T>(
    String path, {
    Object? data,
    DataParser<T>? parser,
    Options? options,
  }) =>
      _run<T>(
        () => _dio.post<dynamic>(path, data: data, options: options),
        parser,
      );

  Future<ApiResult<T>> put<T>(
    String path, {
    Object? data,
    DataParser<T>? parser,
    Options? options,
  }) =>
      _run<T>(
        () => _dio.put<dynamic>(path, data: data, options: options),
        parser,
      );

  Future<ApiResult<T>> delete<T>(
    String path, {
    Object? data,
    DataParser<T>? parser,
    Options? options,
  }) =>
      _run<T>(
        () => _dio.delete<dynamic>(path, data: data, options: options),
        parser,
      );

  /// Multipart upload (`file` field by default) with progress.
  Future<ApiResult<T>> postMultipart<T>(
    String path, {
    required File file,
    String fileKey = 'file',
    String? filename,
    String? contentType,
    Map<String, String>? fields,
    DataParser<T>? parser,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final name = filename ?? file.path.split(Platform.pathSeparator).last;
    final form = FormData();
    fields?.forEach((k, v) => form.fields.add(MapEntry(k, v)));
    form.files.add(
      MapEntry(
        fileKey,
        await MultipartFile.fromFile(
          file.path,
          filename: name,
          contentType:
              contentType == null ? null : DioMediaType.parse(contentType),
        ),
      ),
    );

    return _run<T>(
      () => _dio.post<dynamic>(
        path,
        data: form,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
          sendTimeout: const Duration(minutes: 10),
          receiveTimeout: const Duration(minutes: 2),
        ),
      ),
      parser,
    );
  }

  Future<ApiResult<T>> _run<T>(
    Future<Response<dynamic>> Function() call,
    DataParser<T>? parser,
  ) async {
    try {
      final response = await call();
      final body = response.data;

      if (body is! Map) {
        return const Failure(
          ServerException(message: 'Unexpected response from server.'),
        );
      }

      if (body['success'] == false) {
        final message = body['message'];
        return Failure(
          ServerException(
            message: message is String && message.isNotEmpty
                ? message
                : 'Something went wrong.',
            statusCode: response.statusCode,
          ),
        );
      }

      final parse = parser ?? _identity<T>;
      return Success(parse(body['data']));
    } on AppException catch (e) {
      return Failure(e);
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is AppException) return Failure(inner);
      return Failure(UnknownException(message: e.message ?? 'Unknown error.'));
    } catch (e) {
      return Failure(UnknownException(message: e.toString()));
    }
  }
}
