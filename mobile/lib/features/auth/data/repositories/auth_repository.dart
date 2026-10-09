import '../../../../core/api/api_result.dart';
import '../models/auth_user.dart';

abstract class AuthRepository {
  /// Reads tokens + cached user from storage. `null` = signed out.
  Future<AuthUser?> restoreSession();

  Future<ApiResult<AuthUser>> login({
    required String email,
    required String password,
  });

  /// Creates the account. Does **not** sign in (email must be verified first).
  Future<ApiResult<void>> register({
    required String displayName,
    required String email,
    required String password,
  });

  Future<ApiResult<AuthUser>> loginWithGoogle({
    required String googleId,
    required String email,
    required String displayName,
    String? avatar,
    String? idToken,
  });

  /// Fire-and-forget server logout, then always clears local session.
  Future<void> logout();

  /// Clears local session without calling the server (refresh rejected).
  Future<void> clearLocalSession();

  Future<ApiResult<void>> forgotPassword(String email);

  Future<void> saveUser(AuthUser user);
}
