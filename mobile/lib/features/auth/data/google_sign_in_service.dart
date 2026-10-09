import 'package:google_sign_in/google_sign_in.dart';

/// Plain profile returned by Google (decoupled from the plugin types).
class GoogleProfile {
  const GoogleProfile({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatar,
    this.idToken,
  });

  final String id;
  final String email;
  final String displayName;
  final String? avatar;

  /// Google-signed JWT. The backend must verify it (needs the web client id
  /// passed as GOOGLE_SERVER_CLIENT_ID, otherwise this is null).
  final String? idToken;
}

/// Thin wrapper over `google_sign_in` (v6 API).
///
/// Setup (see README): Android OAuth client with your SHA-1 + a *Web* client
/// id passed as `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
class GoogleSignInService {
  GoogleSignInService()
      : _google = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
        );

  static const String _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  final GoogleSignIn _google;

  /// `null` when the user dismissed the account picker.
  Future<GoogleProfile?> signIn() async {
    final account = await _google.signIn();
    if (account == null) return null;
    final name = account.displayName;
    String? idToken;
    try {
      idToken = (await account.authentication).idToken;
    } catch (_) {
      idToken = null;
    }
    return GoogleProfile(
      id: account.id,
      email: account.email,
      displayName: (name == null || name.trim().isEmpty)
          ? account.email.split('@').first
          : name,
      avatar: account.photoUrl,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Not signed in with Google — nothing to do.
    }
  }
}
