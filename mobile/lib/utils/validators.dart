/// Form validation with the exact RN copy (UI_SPEC §4.2–4.4).
final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

/// Field → message. Empty map = valid.
Map<String, String> validateLogin({
  required String email,
  required String password,
}) {
  final errors = <String, String>{};
  if (email.trim().isEmpty) {
    errors['email'] = 'Email is required';
  } else if (!isValidEmail(email)) {
    errors['email'] = 'Enter a valid email address';
  }
  if (password.isEmpty) errors['password'] = 'Password is required';
  return errors;
}

Map<String, String> validateRegister({
  required String displayName,
  required String email,
  required String password,
  required String confirmPassword,
}) {
  final errors = <String, String>{};
  if (displayName.trim().isEmpty) errors['displayName'] = 'Name is required';

  if (email.trim().isEmpty) {
    errors['email'] = 'Email is required';
  } else if (!isValidEmail(email)) {
    errors['email'] = 'Enter a valid email';
  }

  if (password.isEmpty) {
    errors['password'] = 'Password is required';
  } else if (password.length < 8) {
    errors['password'] = 'Password must be at least 8 characters';
  }

  if (confirmPassword.isEmpty) {
    errors['confirmPassword'] = 'Please confirm your password';
  } else if (password != confirmPassword) {
    errors['confirmPassword'] = 'Passwords do not match';
  }
  return errors;
}

/// Forgot-password email check.
String? validateForgotEmail(String email) {
  if (email.trim().isEmpty) return 'Email is required';
  if (!isValidEmail(email)) return 'Enter a valid email address';
  return null;
}
