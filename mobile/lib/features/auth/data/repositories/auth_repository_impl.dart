import 'dart:async';
import 'dart:convert';

import '../../../../core/api/api_result.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/services/token_service.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/auth_response.dart';
import '../models/auth_user.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenService tokens,
    required StorageService storage,
  })  : _remote = remote,
        _tokens = tokens,
        _storage = storage;

  final AuthRemoteDataSource _remote;
  final TokenService _tokens;
  final StorageService _storage;

  @override
  Future<AuthUser?> restoreSession() async {
    try {
      final access = await _tokens.getAccessToken();
      final refresh = await _tokens.getRefreshToken();
      final json = _storage.userJson;
      if (refresh == null || refresh.isEmpty || json == null) {
        // Half-written state: treat as signed out.
        if (access != null || refresh != null || json != null) {
          await clearLocalSession();
        }
        return null;
      }
      return AuthUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(json) as Map),
      );
    } catch (_) {
      await clearLocalSession();
      return null;
    }
  }

  Future<AuthUser> _persist(AuthResponse r) async {
    await _tokens.saveTokens(
      accessToken: r.accessToken,
      refreshToken: r.refreshToken,
    );
    await _storage.setUserJson(jsonEncode(r.user.toJson()));
    return r.user;
  }

  Future<ApiResult<AuthUser>> _persistResult(ApiResult<AuthResponse> res) async {
    switch (res) {
      case Success<AuthResponse>(data: final d):
        return Success(await _persist(d));
      case Failure<AuthResponse>(exception: final e):
        return Failure(e);
    }
  }

  @override
  Future<ApiResult<AuthUser>> login({
    required String email,
    required String password,
  }) async =>
      _persistResult(await _remote.login(email: email, password: password));

  @override
  Future<ApiResult<void>> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final res = await _remote.register(
      displayName: displayName,
      email: email,
      password: password,
    );
    return res.when<ApiResult<void>>(
      success: (_) => const Success<void>(null),
      failure: (e) => Failure<void>(e),
    );
  }

  @override
  Future<ApiResult<AuthUser>> loginWithGoogle({
    required String googleId,
    required String email,
    required String displayName,
    String? avatar,
    String? idToken,
  }) async =>
      _persistResult(
        await _remote.google(
          googleId: googleId,
          email: email,
          displayName: displayName,
          avatar: avatar,
          idToken: idToken,
        ),
      );

  @override
  Future<void> logout() async {
    try {
      final refresh = await _tokens.getRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        // Fire and forget: never block logout on the network.
        unawaited(_remote.logout(refresh));
      }
    } finally {
      await clearLocalSession();
    }
  }

  @override
  Future<void> clearLocalSession() async {
    await _tokens.clearTokens();
    await _storage.clearUser();
  }

  @override
  Future<ApiResult<void>> forgotPassword(String email) =>
      _remote.forgotPassword(email);

  @override
  Future<void> saveUser(AuthUser user) =>
      _storage.setUserJson(jsonEncode(user.toJson()));
}
