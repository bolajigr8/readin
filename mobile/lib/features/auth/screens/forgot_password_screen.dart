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
import '../providers/auth_providers.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_link_row.dart';

/// UI_SPEC §4.4 — Forgot password. Always ends on the success state.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _emailError;
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
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
    final err = validateForgotEmail(_email.text);
    if (err != null) {
      setState(() => _emailError = err);
      return;
    }
    setState(() {
      _emailError = null;
      _isLoading = true;
    });
    // Always show success — the server never reveals whether the email exists.
    try {
      await ref.read(authProvider.notifier).forgotPassword(_email.text);
    } catch (_) {
      // Swallowed on purpose (avoids email enumeration).
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthScrollBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthBackLink(onTap: _back),
            const SizedBox(height: 32),
            if (_submitted) ...[
              AuthSuccessBlock(
                circleColor: AppColors.alpha(AppColors.primary500, 0x33),
                emoji: '✉️',
                title: 'Email sent',
                message:
                    "If an account with that email exists, we've sent a reset link. Check your inbox and spam folder.",
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Back to Sign In',
                variant: AppButtonVariant.outline,
                size: AppButtonSize.lg,
                expand: true,
                onPressed: () => context.go(AppRoutes.signIn),
              ),
            ] else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reset password',
                    style: AppTypography.label(
                      size: 36,
                      weight: FontWeight.w700,
                      lineHeight: 40,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Enter your email and we'll send a reset link",
                    style: AppTypography.label(
                      size: 16,
                      color: AppColors.textSecondary,
                      lineHeight: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                leftIcon: Ionicons.mail_outline,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                error: _emailError,
              ),
              const SizedBox(height: 32),
              AppButton(
                label: 'Send Reset Link',
                size: AppButtonSize.lg,
                expand: true,
                loading: _isLoading,
                onPressed: _submit,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
