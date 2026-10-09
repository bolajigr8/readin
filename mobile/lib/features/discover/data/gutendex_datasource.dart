import 'package:dio/dio.dart';

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';
import 'gutenberg_models.dart';

/// Talks to the public Gutendex API. Uses its **own** Dio: no auth header
/// (our JWT must never leak to a third party), normal User-Agent, 20 s
/// timeouts, redirects followed.
class GutendexDataSource {
  GutendexDataSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://gutendex.com',
                connectTimeout: const Duration(seconds: 20),
                receiveTimeout: const Duration(seconds: 20),
                sendTimeout: const Duration(seconds: 20),
                followRedirects: true,
                maxRedirects: 5,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent': 'ReadIn/1.0 (Flutter; Android) Dart/3',
                },
              ),
            );

  final Dio _dio;

  Future<ApiResult<GutenbergPage>> popular({int page = 1}) =>
      _page({'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergPage>> search(String query, {int page = 1}) =>
      _page({'search': query, 'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergPage>> byTopic(String topic, {int page = 1}) =>
      _page({'topic': topic, 'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergBook>> byId(int id) async {
    try {
      final res = await _dio.get<dynamic>('/books/$id');
      final data = res.data;
      if (data is! Map) {
        return const Failure(ServerException(message: 'Unexpected response.'));
      }
      return Success(GutenbergBook.fromJson(Map<String, dynamic>.from(data)));
    } on DioException catch (e) {
      return Failure(_map(e));
    } catch (e) {
      return Failure(UnknownException(message: e.toString()));
    }
  }

  Future<ApiResult<GutenbergPage>> _page(Map<String, dynamic> query) async {
    try {
      final res = await _dio.get<dynamic>('/books', queryParameters: query);
      final data = res.data;
      if (data is! Map) {
        return const Failure(ServerException(message: 'Unexpected response.'));
      }
      return Success(GutenbergPage.fromJson(Map<String, dynamic>.from(data)));
    } on DioException catch (e) {
      return Failure(_map(e));
    } catch (e) {
      return Failure(UnknownException(message: e.toString()));
    }
  }

  AppException _map(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) return const NotFoundException(message: 'Book not found.');
        return ServerException(
          message: 'Gutenberg is unavailable right now (HTTP $code).',
          statusCode: code,
        );
      default:
        if (e.error.toString().contains('SocketException')) {
          return const NetworkException();
        }
        return const UnknownException();
    }
  }
}
