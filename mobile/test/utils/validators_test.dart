import 'package:flutter_test/flutter_test.dart';

import 'package:readin_flutter/core/errors/app_exception.dart';
import 'package:readin_flutter/features/auth/utils/auth_error_messages.dart';
import 'package:readin_flutter/utils/validators.dart';

void main() {
  group('login validation (RN copy)', () {
    test('empty', () {
      final e = validateLogin(email: '  ', password: '');
      expect(e['email'], 'Email is required');
      expect(e['password'], 'Password is required');
    });
    test('bad email', () {
      expect(
        validateLogin(email: 'nope', password: 'x')['email'],
        'Enter a valid email address',
      );
    });
    test('valid (trailing space tolerated)', () {
      expect(validateLogin(email: ' a@b.co ', password: 'x'), isEmpty);
    });
  });

  group('register validation', () {
    Map<String, String> v({
      String name = 'Al',
      String email = 'a@b.co',
      String pw = 'password1',
      String confirm = 'password1',
    }) =>
        validateRegister(
          displayName: name,
          email: email,
          password: pw,
          confirmPassword: confirm,
        );

    test('ok', () => expect(v(), isEmpty));
    test('name', () => expect(v(name: ' ')['displayName'], 'Name is required'));
    test('email copy differs from login', () {
      expect(v(email: 'x')['email'], 'Enter a valid email');
    });
    test('short password', () {
      expect(
        v(pw: '1234567', confirm: '1234567')['password'],
        'Password must be at least 8 characters',
      );
    });
    test('confirm missing / mismatch', () {
      expect(v(confirm: '')['confirmPassword'], 'Please confirm your password');
      expect(v(confirm: 'other')['confirmPassword'], 'Passwords do not match');
    });
  });

  test('forgot email', () {
    expect(validateForgotEmail(''), 'Email is required');
    expect(validateForgotEmail('x'), 'Enter a valid email address');
    expect(validateForgotEmail('a@b.co'), isNull);
  });

  group('register error mapping', () {
    test('409 -> email field', () {
      final m = registerErrorMapping(
        const ServerException(message: 'dup', statusCode: 409),
      );
      expect(m.emailError, 'An account with this email already exists.');
      expect(m.general, isNull);
    });
    test('network', () {
      expect(
        registerErrorMapping(const NetworkException()).general,
        'Network error. Check your connection.',
      );
    });
    test('server message passes through', () {
      expect(
        registerErrorMapping(
          const ServerException(message: 'Password too weak', statusCode: 400),
        ).general,
        'Password too weak',
      );
    });
  });
}
