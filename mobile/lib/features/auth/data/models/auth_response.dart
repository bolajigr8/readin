import 'auth_user.dart';

/// `{accessToken, refreshToken, user}` from register / login / google.
class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: (json['accessToken'] ?? '').toString(),
      refreshToken: (json['refreshToken'] ?? '').toString(),
      user: AuthUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
      ),
    );
  }
}
