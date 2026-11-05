import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/api_result.dart';
import '../../../core/errors/app_exception.dart';
import 'gutenberg_models.dart';

/// Where the last good first page of each list is kept, so Discover still shows
/// books when the free Gutendex service is slow or down.
abstract class GutendexCache {
  String? read(String key);
  Future<void> write(String key, String value);
}

/// Talks to the public Gutendex API. Uses its **own** Dio: no auth header
/// (our JWT must never leak to a third party), normal User-Agent, 20 s
/// timeouts, redirects followed.
class GutendexDataSource {
  GutendexDataSource({
    Dio? dio,
    GutendexCache? cache,
    this.retryDelay = const Duration(milliseconds: 1500),
  })  : _cache = cache,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://gutendex.com',
                connectTimeout: const Duration(seconds: 20),
                // the free Gutendex server can take a long time on its busiest lists
                receiveTimeout: const Duration(seconds: 45),
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
  final GutendexCache? _cache;

  /// Pause before the 2nd and 3rd attempt (×1, ×2).
  final Duration retryDelay;

  Future<ApiResult<GutenbergPage>> popular({int page = 1}) =>
      _page({'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergPage>> search(String query, {int page = 1}) =>
      _page({'search': query, 'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergPage>> byTopic(String topic, {int page = 1}) =>
      _page({'topic': topic, 'languages': 'en', 'page': page});

  Future<ApiResult<GutenbergBook>> byId(int id) async {
    try {
      final res = await _get('/books/$id');
      final data = _asMap(res.data);
      if (data == null) {
        return const Failure(ServerException(message: 'Unexpected response.'));
      }
      return Success(GutenbergBook.fromJson(data));
    } on DioException catch (e) {
      return Failure(_map(e));
    } catch (e) {
      return Failure(UnknownException(message: e.toString()));
    }
  }

  static bool _retryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final c = e.response?.statusCode ?? 0;
        return c >= 500 || c == 429;
      default:
        return false;
    }
  }

  /// GET with up to 3 attempts (timeouts, connection errors, 5xx, 429).
  Future<Response<dynamic>> _get(String path, [Map<String, dynamic>? query]) async {
    for (var attempt = 1;; attempt++) {
      try {
        return await _dio.get<dynamic>(path, queryParameters: query);
      } on DioException catch (e) {
        debugPrint('[Gutendex] GET $path $query failed (attempt $attempt): '
            '${e.type} status=${e.response?.statusCode} error=${e.error}');
        if (attempt >= 3 || !_retryable(e)) rethrow;
        await Future<void>.delayed(retryDelay * attempt);
      }
    }
  }

  static String _key(Map<String, dynamic> q) {
    final keys = q.keys.toList()..sort();
    return keys.map((k) => '$k=${q[k]}').join('&');
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final j = jsonDecode(data);
        if (j is Map) return Map<String, dynamic>.from(j);
      } catch (_) {}
    }
    return null;
  }

  Future<ApiResult<GutenbergPage>> _page(Map<String, dynamic> query) async {
    final cacheKey = _key(query);
    final isFirst = (query['page'] ?? 1) == 1;
    try {
      final res = await _get('/books', query);
      final data = _asMap(res.data);
      if (data == null) {
        return const Failure(ServerException(message: 'Unexpected response.'));
      }
      if (isFirst) {
        // keep the last good first page for the days Gutendex is down
        unawaited(_cache?.write(cacheKey, jsonEncode(data)) ?? Future<void>.value());
      }
      return Success(GutenbergPage.fromJson(data));
    } on DioException catch (e) {
      final saved = isFirst ? _cache?.read(cacheKey) : null;
      if (saved != null) {
        final j = _asMap(saved);
        if (j != null) return Success(GutenbergPage.fromJson(j, fromCache: true));
      }
      return Failure(_map(e));
    } catch (e) {
      return Failure(UnknownException(message: e.toString()));
    }
  }

  AppException _map(DioException e) {
    // A failed TLS handshake is usually a wrong phone date/time or a Wi-Fi
    // login page (captive portal) — say so instead of "no internet".
    if (e.error is HandshakeException) {
      return const ServerException(
        message: 'The secure connection to Project Gutenberg failed. '
            "Check the phone's date and time, and that the Wi-Fi does not need a login.",
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const RequestTimeoutException(
          message: 'Project Gutenberg\'s catalogue (gutendex.com) is slow or not answering right now.',
        );
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 404) return const NotFoundException(message: 'Book not found.');
        return ServerException(
          message: 'Project Gutenberg\'s catalogue is unavailable right now (HTTP $code).',
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
