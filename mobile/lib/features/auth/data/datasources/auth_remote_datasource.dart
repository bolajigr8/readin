import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_endpoints.dart';
import '../../../../core/api/api_result.dart';
import '../models/auth_response.dart';

abstract class AuthRemoteDataSource {
  Future<ApiResult<AuthResponse>> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<ApiResult<AuthResponse>> login({
    required String email,
    required String password,
  });

  Future<ApiResult<AuthResponse>> google({
    required String googleId,
    required String email,
    required String displayName,
    String? avatar,
    String? idToken,
  });

  Future<ApiResult<String>> refresh(String refreshToken);

  Future<ApiResult<void>> logout(String refreshToken);

  Future<ApiResult<void>> forgotPassword(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  AuthRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  AuthResponse _parseAuth(dynamic d) =>
      AuthResponse.fromJson(Map<String, dynamic>.from(d as Map));

  @override
  Future<ApiResult<AuthResponse>> register({
    required String displayName,
    required String email,
    required String password,
  }) =>
      _api.post<AuthResponse>(
        ApiEndpoints.register,
        data: {'displayName': displayName, 'email': email, 'password': password},
        parser: _parseAuth,
      );

  @override
  Future<ApiResult<AuthResponse>> login({
    required String email,
    required String password,
  }) =>
      _api.post<AuthResponse>(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
        parser: _parseAuth,
      );

  @override
  Future<ApiResult<AuthResponse>> google({
    required String googleId,
    required String email,
    required String displayName,
    String? avatar,
    String? idToken,
  }) =>
      _api.post<AuthResponse>(
        ApiEndpoints.google,
        data: {
          'googleId': googleId,
          'email': email,
          'displayName': displayName,
          // Server validates `avatar` as a URL: omit it rather than send ''.
          if (avatar != null && avatar.isNotEmpty) 'avatar': avatar,
          // Lets the server verify the sign-in with Google (see notes).
          if (idToken != null && idToken.isNotEmpty) 'idToken': idToken,
        },
        parser: _parseAuth,
      );

  @override
  Future<ApiResult<String>> refresh(String refreshToken) => _api.post<String>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
        parser: (d) => (d as Map)['accessToken'] as String,
      );

  @override
  Future<ApiResult<void>> logout(String refreshToken) => _api.post<void>(
        ApiEndpoints.logout,
        data: {'refreshToken': refreshToken},
        parser: (_) {},
      );

  @override
  Future<ApiResult<void>> forgotPassword(String email) => _api.post<void>(
        ApiEndpoints.forgotPassword,
        data: {'email': email},
        parser: (_) {},
      );
}
