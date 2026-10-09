import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../../constants/app_colors.dart';
import '../../../core/services/routes.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/error_banner.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_link_row.dart';

/// UI_SPEC §4.3 — Register (+ "Check your inbox" success state).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  Map<String, String> _errors = {};
  String? _general;
  bool _isLoading = false;
  String? _successMessage;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.signIn);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final errors = validateRegister(
      displayName: _name.text,
      email: _email.text,
      password: _password.text,
      confirmPassword: _confirm.text,
    );
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _general = null;
      });
      return;
    }
    setState(() {
      _errors = {};
      _general = null;
      _isLoading = true;
    });

    final ok = await ref.read(authProvider.notifier).register(
          displayName: _name.text,
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;

    if (ok) {
      setState(() {
        _isLoading = false;
        _successMessage =
            'Account created! Check your email to verify your account before logging in.';
      });
      return;
    }

    final err = ref.read(authProvider).error;
    final mapped = err == null ? null : registerErrorMapping(err);
    setState(() {
      _isLoading = false;
      if (mapped?.emailError != null) _errors = {'email': mapped!.emailError!};
      _general = mapped?.general;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_successMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthSuccessBlock(
                    circleColor: AppColors.alpha(AppColors.success500, 0x33),
                    emoji: '📬',
                    title: 'Check your inbox',
                    message: _successMessage!,
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Back to Sign In',
                    size: AppButtonSize.lg,
                    expand: true,
                    onPressed: () => context.go(AppRoutes.signIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: AuthScrollBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBackLink(onTap: _back),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create account',
                  style: AppTypography.label(
                    size: 36,
                    weight: FontWeight.w700,
                    lineHeight: 40,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your reading journey',
                  style: AppTypography.label(
                    size: 16,
                    color: AppColors.textSecondary,
                    lineHeight: 24,
                  ),
                ),
              ],
            ),
            if (_general != null) ...[
              const SizedBox(height: 32),
              ErrorBanner(
                message: _general!,
                fillAlpha: 0x1A,
                borderAlpha: 0x4D,
                radius: 12,
              ),
            ],
            const SizedBox(height: 32),
            AppTextField(
              controller: _name,
              label: 'Display Name',
              hint: 'Your name',
              leftIcon: Ionicons.person_outline,
              textInputAction: TextInputAction.next,
              error: _errors['displayName'],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _email,
              label: 'Email',
              hint: 'you@example.com',
              leftIcon: Ionicons.mail_outline,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              error: _errors['email'],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _password,
              label: 'Password',
              hint: 'Min. 8 characters',
              leftIcon: Ionicons.lock_closed_outline,
              isPassword: true,
              textInputAction: TextInputAction.next,
              error: _errors['password'],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirm,
              label: 'Confirm Password',
              hint: 'Repeat your password',
              leftIcon: Ionicons.lock_closed_outline,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              error: _errors['confirmPassword'],
            ),
            const SizedBox(height: 32),
            AppButton(
              label: 'Create Account',
              size: AppButtonSize.lg,
              expand: true,
              loading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: 32),
            AuthLinkRow(
              prompt: 'Already have an account?',
              action: 'Sign in',
              lineHeight: 20,
              onTap: () => context.go(AppRoutes.signIn),
            ),
          ],
        ),
      ),
    );
  }
}
