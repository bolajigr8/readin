import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/api/api_client.dart';
import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/core/services/token_service.dart';

typedef TestReply = ({int status, Object body});

/// Fake HTTP adapter: records requests, answers with [handler].
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final TestReply Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Drain the body like a real adapter (multipart bodies are streams).
    if (requestStream != null) {
      await requestStream.drain<void>();
    }
    requests.add(options);
    final r = handler(options);
    return ResponseBody.fromString(
      jsonEncode(r.body),
      r.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class MemoryStorage extends StorageService {
  MemoryStorage(SharedPreferences prefs) : super(prefs: prefs);

  final Map<SecureStorageKey, String> _m = {};

  @override
  Future<String?> readSecure(SecureStorageKey k) async => _m[k];

  @override
  Future<void> writeSecure(SecureStorageKey k, String value) async => _m[k] = value;

  @override
  Future<void> deleteSecure(SecureStorageKey k) async => _m.remove(k);
}

const testBase = 'https://test.local/api/v1';

/// Builds an [ApiClient] wired to [adapter] with a signed-in token.
Future<ApiClient> makeTestApi(FakeAdapter adapter) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = MemoryStorage(prefs);
  await storage.setAccessToken('tok');
  await storage.setRefreshToken('ref');
  final refreshDio = Dio(BaseOptions(baseUrl: testBase))..httpClientAdapter = adapter;
  return ApiClient(
    tokenService: TokenService(storage: storage, refreshDio: refreshDio),
    adapter: adapter,
    baseUrl: testBase,
    onSessionExpired: () async {},
  );
}
