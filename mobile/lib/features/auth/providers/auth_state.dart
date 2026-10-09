import '../../../core/errors/app_exception.dart';
import '../data/models/auth_user.dart';

enum AuthStatus {
  /// Nothing happened yet.
  initial,

  /// A login / register / google request is running.
  loading,
  authenticated,
  unauthenticated,

  /// User pressed Sign Out.
  loggedOut,

  /// Account created; waiting for email verification.
  registered,
  error,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isHydrated = false,
  });

  final AuthStatus status;
  final AuthUser? user;

  /// Last failure (use `error.statusCode` to pick the exact RN message).
  final AppException? error;

  /// True once stored tokens/user have been read (router waits for this).
  final bool isHydrated;

  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;
  bool get isLoading => status == AuthStatus.loading;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    bool clearUser = false,
    AppException? error,
    bool clearError = false,
    bool? isHydrated,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      isHydrated: isHydrated ?? this.isHydrated,
    );
  }
}
