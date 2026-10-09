import '../../../core/errors/app_exception.dart';

/// Exact RN login error copy (UI_SPEC §4.2).
String loginErrorMessage(AppException e) {
  if (e is NetworkException || e is RequestTimeoutException) {
    return 'Network error. Check your internet connection.';
  }
  switch (e.statusCode) {
    case 403:
      return e.message; // e.g. "verify your email" (server wording)
    case 401:
      return 'Incorrect email or password.';
    case 429:
      return 'Too many login attempts. Please wait a few minutes and try again.';
    default:
      return 'Something went wrong. Please try again.';
  }
}

/// Result of mapping a register failure to the right place on the form.
class RegisterErrorMapping {
  const RegisterErrorMapping({this.emailError, this.general});

  final String? emailError;
  final String? general;
}

/// Exact RN register error copy (UI_SPEC §4.3).
RegisterErrorMapping registerErrorMapping(AppException e) {
  if (e is NetworkException || e is RequestTimeoutException) {
    return const RegisterErrorMapping(
      general: 'Network error. Check your connection.',
    );
  }
  if (e.statusCode == 409) {
    return const RegisterErrorMapping(
      emailError: 'An account with this email already exists.',
    );
  }
  return RegisterErrorMapping(
    general: e.message.isEmpty
        ? 'Registration failed. Please try again.'
        : e.message,
  );
}
