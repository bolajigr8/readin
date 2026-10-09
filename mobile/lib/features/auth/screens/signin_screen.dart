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
import '../../../widgets/pressable_opacity.dart';
import '../providers/auth_providers.dart';
import '../utils/auth_error_messages.dart';
import '../widgets/auth_layout.dart';
import '../widgets/auth_link_row.dart';
import '../widgets/entrance_group.dart';

/// UI_SPEC §4.2 — Login. On success the router redirect moves to Home.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _general;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    final errors = validateLogin(email: _email.text, password: _password.text);
    if (errors.isNotEmpty) {
      setState(() {
        _emailError = errors['email'];
        _passwordError = errors['password'];
        _general = null;
      });
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
      _general = null;
      _isLoading = true;
    });

    final ok = await ref
        .read(authProvider.notifier)
        .login(email: _email.text, password: _password.text);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (!ok) {
        final err = ref.read(authProvider).error;
        _general = err == null ? null : loginErrorMessage(err);
      }
    });
  }

  Future<void> _google() async {
    if (_isGoogleLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _general = null;
      _isGoogleLoading = true;
    });
    final ok = await ref.read(authProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    setState(() {
      _isGoogleLoading = false;
      if (!ok) {
        // `error == null` means the user just closed the account picker.
        _general = ref.read(authProvider).error?.message;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuthScrollBody(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
        child: StaggeredEntrance(
          children: [
            _header(),
            _form(),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: AppTypography.label(size: 36, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue reading',
            style: AppTypography.label(size: 16, color: AppColors.textSecondary),
          ),
        ],
      );

  Widget _form() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_general != null) ...[
            ErrorBanner(message: _general!),
            const SizedBox(height: 16),
          ],
          AppTextField(
            controller: _email,
            label: 'Email',
            hint: 'you@example.com',
            leftIcon: Ionicons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            error: _emailError,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _password,
            label: 'Password',
            hint: '••••••••',
            leftIcon: Ionicons.lock_closed_outline,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
            error: _passwordError,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRoutes.forgot),
              child: Text(
                'Forgot password?',
                style: AppTypography.label(
                  size: 14,
                  weight: FontWeight.w500,
                  color: AppColors.primary500,
                ),
              ),
            ),
          ),
        ],
      );

  Widget _footer() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Sign In',
            size: AppButtonSize.lg,
            expand: true,
            loading: _isLoading,
            onPressed: _login,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: _Line()),
              const SizedBox(width: 12),
              Text(
                'or continue with',
                style: AppTypography.label(size: 12, color: AppColors.textMuted),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _Line()),
            ],
          ),
          const SizedBox(height: 16),
          _GoogleButton(loading: _isGoogleLoading, onTap: _google),
          const SizedBox(height: 16),
          AuthLinkRow(
            prompt: "Don't have an account?",
            action: 'Sign up',
            onTap: () => context.push(AppRoutes.signUp),
          ),
        ],
      );
}

class _Line extends StatelessWidget {
  const _Line();

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: AppColors.borderDefault);
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.8,
      onTap: loading ? null : onTap,
      child: Opacity(
        opacity: loading ? 0.65 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Ionicons.logo_google,
                size: 20,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Text(
                loading ? 'Signing in...' : 'Continue with Google',
                style: AppTypography.label(size: 16, weight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
