import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:readin_flutter/core/api/api_client.dart';
import 'package:readin_flutter/core/api/api_result.dart';
import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/core/services/storage_service.dart';
import 'package:readin_flutter/core/services/token_service.dart';
import 'package:readin_flutter/features/auth/utils/auth_error_messages.dart';

typedef _Reply = ({int status, Object body});

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final _Reply Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    // Yield so concurrent requests really overlap.
    await Future<void>.delayed(const Duration(milliseconds: 5));
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

class _MemoryStorage extends StorageService {
  _MemoryStorage(SharedPreferences prefs) : super(prefs: prefs);

  final Map<SecureStorageKey, String> _m = {};

  @override
  Future<String?> readSecure(SecureStorageKey k) async => _m[k];

  @override
  Future<void> writeSecure(SecureStorageKey k, String value) async =>
      _m[k] = value;

  @override
  Future<void> deleteSecure(SecureStorageKey k) async => _m.remove(k);
}

class _Rig {
  _Rig(this.api, this.storage);
  final ApiClient api;
  final _MemoryStorage storage;
  int expired = 0;
  int refreshCalls = 0;
  int libraryCalls = 0;
}

const _base = 'https://test.local/api/v1';

Future<_Rig> _makeRig({
  required _Reply Function(RequestOptions o, _Rig rig) handler,
  bool withRefreshToken = true,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final storage = _MemoryStorage(prefs);
  await storage.setAccessToken('old');
  if (withRefreshToken) await storage.setRefreshToken('r1');

  late _Rig rig;
  final adapter = _FakeAdapter((o) => handler(o, rig));
  final refreshDio = Dio(BaseOptions(baseUrl: _base))
    ..httpClientAdapter = adapter;
  final tokens = TokenService(storage: storage, refreshDio: refreshDio);

  final api = ApiClient(
    tokenService: tokens,
    adapter: adapter,
    baseUrl: _base,
    onSessionExpired: () async => rig.expired++,
  );
  rig = _Rig(api, storage);
  return rig;
}

_Reply _ok(Object data) =>
    (status: 200, body: {'success': true, 'message': 'ok', 'data': data});

_Reply _fail(int status, String message) =>
    (status: status, body: {'success': false, 'message': message});

Future<ApiResult<Map<String, dynamic>>> _getLibrary(_Rig rig) =>
    rig.api.get<Map<String, dynamic>>(
      '/library',
      parser: (d) => Map<String, dynamic>.from(d as Map),
    );

/// Default handler: /library needs "Bearer new"; /auth/refresh issues "new".
_Reply _standard(RequestOptions o, _Rig rig) {
  if (o.path == '/auth/refresh') {
    rig.refreshCalls++;
    return _ok({'accessToken': 'new'});
  }
  if (o.path == '/library') {
    rig.libraryCalls++;
    if (o.headers['Authorization'] == 'Bearer new') {
      return _ok({'books': <dynamic>[]});
    }
    return _fail(401, 'jwt expired');
  }
  return _fail(404, 'nope');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('401 -> refresh -> retry once', () async {
    final rig = await _makeRig(handler: _standard);
    final res = await _getLibrary(rig);

    expect(res.isSuccess, isTrue);
    expect(rig.refreshCalls, 1);
    expect(rig.libraryCalls, 2); // original + one retry
    expect(await rig.storage.accessToken, 'new');
  });

  test('two simultaneous 401s trigger ONE refresh', () async {
    final rig = await _makeRig(handler: _standard);
    final results = await Future.wait([_getLibrary(rig), _getLibrary(rig)]);

    expect(results.every((r) => r.isSuccess), isTrue);
    expect(rig.refreshCalls, 1);
  });

  test('refresh rejected -> session cleared + onSessionExpired', () async {
    final rig = await _makeRig(handler: (o, rig) {
      if (o.path == '/auth/refresh') {
        rig.refreshCalls++;
        return _fail(401, 'Invalid refresh token');
      }
      return _fail(401, 'jwt expired');
    });

    final res = await _getLibrary(rig);

    expect(res.isFailure, isTrue);
    expect(res.exceptionOrNull, isA<UnauthorizedException>());
    expect(rig.expired, 1);
    expect(await rig.storage.accessToken, isNull);
    expect(await rig.storage.refreshToken, isNull);
  });

  test('no refresh token -> logs out without calling /auth/refresh', () async {
    final rig = await _makeRig(
      withRefreshToken: false,
      handler: (o, rig) {
        if (o.path == '/auth/refresh') rig.refreshCalls++;
        return _fail(401, 'jwt expired');
      },
    );

    final res = await _getLibrary(rig);
    expect(res.isFailure, isTrue);
    expect(rig.refreshCalls, 0);
    expect(rig.expired, 1);
  });

  test('401 on /auth/login does NOT refresh (wrong password)', () async {
    final rig = await _makeRig(handler: (o, rig) {
      if (o.path == '/auth/refresh') rig.refreshCalls++;
      return _fail(401, 'Invalid credentials');
    });

    final res = await rig.api.post<Object?>(
      '/auth/login',
      data: {'email': 'a@b.co', 'password': 'x'},
    );

    expect(res.isFailure, isTrue);
    expect(res.exceptionOrNull?.statusCode, 401);
    expect(rig.refreshCalls, 0);
    expect(rig.expired, 0);
    expect(
      loginErrorMessage(res.exceptionOrNull!),
      'Incorrect email or password.',
    );
  });

  test('{success:false} body becomes Failure(ServerException)', () async {
    final rig = await _makeRig(
      handler: (o, rig) => (
        status: 200,
        body: {'success': false, 'message': 'Boom from server'},
      ),
    );

    final res = await _getLibrary(rig);
    expect(res, isA<Failure<Map<String, dynamic>>>());
    final ex = res.exceptionOrNull;
    expect(ex, isA<ServerException>());
    expect(ex?.message, 'Boom from server');
  });

  test('login error copy matches RN', () {
    expect(
      loginErrorMessage(const ForbiddenException(message: 'Verify your email')),
      'Verify your email',
    );
    expect(
      loginErrorMessage(const RateLimitException()),
      'Too many login attempts. Please wait a few minutes and try again.',
    );
    expect(
      loginErrorMessage(const NetworkException()),
      'Network error. Check your internet connection.',
    );
    expect(
      loginErrorMessage(const ServerException(message: 'x', statusCode: 500)),
      'Something went wrong. Please try again.',
    );
  });
}
