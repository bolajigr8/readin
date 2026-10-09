import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/services/global_error_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/token_service.dart';
import '../../../providers/theme_provider.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/models/auth_user.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/google_sign_in_service.dart';
import 'auth_state.dart';

// ── Core providers ───────────────────────────────────────────────────────────

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(prefs: ref.watch(sharedPreferencesProvider)),
);

final tokenServiceProvider = Provider<TokenService>(
  (ref) => TokenService(storage: ref.watch(storageServiceProvider)),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenService: ref.watch(tokenServiceProvider),
    // Called by the auth interceptor when the refresh token is rejected.
    onSessionExpired: () async {
      await ref.read(authProvider.notifier).sessionExpired();
    },
  );
});

// ── Auth chain ───────────────────────────────────────────────────────────────

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>(
  (ref) => AuthRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(
    remote: ref.watch(authRemoteDataSourceProvider),
    tokens: ref.watch(tokenServiceProvider),
    storage: ref.watch(storageServiceProvider),
  ),
);

final googleSignInServiceProvider = Provider<GoogleSignInService>(
  (ref) => GoogleSignInService(),
);

/// Whether the onboarding walkthrough has been completed (router listens).
final onboardingCompleteProvider = StateProvider<bool>(
  (ref) => ref.watch(storageServiceProvider).onboardingComplete,
);

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref),
);

/// Convenience: current user (null when signed out).
final currentUserProvider = Provider<AuthUser?>(
  (ref) => ref.watch(authProvider).user,
);

const String _googleFailedCopy =
    'Google sign-in failed. Please try again or use email/password.';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    hydrate();
  }

  final Ref _ref;

  AuthRepository get _repo => _ref.read(authRepositoryProvider);

  /// RN `hydrate()`: restore session from storage.
  Future<void> hydrate() async {
    final user = await _repo.restoreSession();
    if (!mounted) return;
    state = user == null
        ? const AuthState(status: AuthStatus.unauthenticated, isHydrated: true)
        : AuthState(
            status: AuthStatus.authenticated,
            user: user,
            isHydrated: true,
          );
  }

  /// RN `login`. Returns true on success; on failure `state.error` is set.
  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final res = await _repo.login(
      email: email.toLowerCase().trim(),
      password: password,
    );
    if (!mounted) return false;
    return res.when(
      success: (user) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          isHydrated: true,
        );
        return true;
      },
      failure: (e) {
        state = AuthState(
          status: AuthStatus.error,
          error: e,
          isHydrated: true,
        );
        return false;
      },
    );
  }

  Future<bool> register({
    required String displayName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    final res = await _repo.register(
      displayName: displayName.trim(),
      email: email.toLowerCase().trim(),
      password: password,
    );
    if (!mounted) return false;
    return res.when(
      success: (_) {
        state = const AuthState(status: AuthStatus.registered, isHydrated: true);
        return true;
      },
      failure: (e) {
        state = AuthState(status: AuthStatus.error, error: e, isHydrated: true);
        return false;
      },
    );
  }

  /// Google sign-in → POST /auth/google. Returns false if the user cancelled
  /// (no error set) or on failure (error set).
  Future<bool> loginWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);
    try {
      final account = await _ref.read(googleSignInServiceProvider).signIn();
      if (account == null) {
        if (mounted) {
          state = const AuthState(
            status: AuthStatus.unauthenticated,
            isHydrated: true,
          );
        }
        return false;
      }
      final res = await _repo.loginWithGoogle(
        googleId: account.id,
        email: account.email,
        displayName: account.displayName,
        avatar: account.avatar,
        idToken: account.idToken,
      );
      if (!mounted) return false;
      return res.when(
        success: (user) {
          state = AuthState(
            status: AuthStatus.authenticated,
            user: user,
            isHydrated: true,
          );
          return true;
        },
        failure: (e) {
          debugPrint('[Google Auth] backend rejected sign-in: ${e.message}');
          state = const AuthState(
            status: AuthStatus.error,
            error: UnknownException(message: _googleFailedCopy),
            isHydrated: true,
          );
          return false;
        },
      );
    } catch (e) {
      // Typical causes: wrong SHA-1 / package (ApiException 10), missing
      // serverClientId, no Play services. Real cause is in the debug log.
      debugPrint('[Google Auth] sign-in failed: $e');
      if (!mounted) return false;
      state = const AuthState(
        status: AuthStatus.error,
        error: UnknownException(message: _googleFailedCopy),
        isHydrated: true,
      );
      return false;
    }
  }

  Future<void> forgotPassword(String email) async {
    // RN always shows the success screen, whatever the server says.
    await _repo.forgotPassword(email.toLowerCase().trim());
  }

  /// RN `logout`: fire-and-forget API call, then clear everything.
  Future<void> logout() async {
    await _repo.logout();
    await _ref.read(googleSignInServiceProvider).signOut();
    if (!mounted) return;
    state = const AuthState(status: AuthStatus.loggedOut, isHydrated: true);
  }

  /// Refresh token was rejected: the interceptor already cleared tokens.
  Future<void> sessionExpired() async {
    if (!mounted || state.status == AuthStatus.loggedOut) return;
    await _repo.clearLocalSession();
    if (!mounted) return;
    state = const AuthState(
      status: AuthStatus.unauthenticated,
      isHydrated: true,
    );
    _ref.read(globalErrorProvider.notifier).state =
        GlobalError('Session expired. Please sign in again.');
  }

  /// RN `setUser` (e.g. after plan change).
  Future<void> setUser(AuthUser user) async {
    await _repo.saveUser(user);
    if (!mounted) return;
    state = state.copyWith(user: user);
  }

  void clearError() {
    state = state.copyWith(clearError: true, status: AuthStatus.unauthenticated);
  }
}
