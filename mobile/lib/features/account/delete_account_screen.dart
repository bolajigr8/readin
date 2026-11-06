import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../app/app_restart.dart';
import '../../constants/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/pressable_opacity.dart';
import 'account_deletion.dart';

/// Profile → Delete account (S7.1). Explains what happens, asks for the password
/// and the word DELETE, then deletes on the server and wipes this phone.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready => !_busy && _password.text.isNotEmpty && _confirm.text.trim().toUpperCase() == 'DELETE';

  Future<void> _delete() async {
    if (!_ready) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final deletion = ref.read(accountDeletionProvider);
    final res = await deletion.deleteOnServer(_password.text);
    if (!mounted) return;
    final err = res.exceptionOrNull;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err.message;
      });
      return;
    }
    // The server deleted the account → now this phone (books, settings, reminders, sign-in).
    await deletion.wipeThisPhone();
    AppToast.success('Your account was deleted. Thank you for reading with ReadIn.');
    if (!mounted) return;
    AppRestart.restart(context); // fresh-install state: every provider starts over
  }

  @override
  Widget build(BuildContext context) {
    Widget item(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Ionicons.close_circle, size: 16, color: AppColors.error400),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text, style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 20)),
              ),
            ],
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressableOpacity(
                pressedOpacity: 0.7,
                semanticLabel: 'Back',
                onTap: _busy ? null : () => context.pop(),
                child: const SizedBox(width: 56, height: 56, child: Icon(Ionicons.arrow_back)),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Delete your account', style: AppTypography.title22),
                    const SizedBox(height: 8),
                    Text(
                      'This permanently deletes your ReadIn account. It cannot be undone.',
                      style: AppTypography.label(size: 14, color: AppColors.textSecondary, lineHeight: 21),
                    ),
                    const SizedBox(height: 18),
                    item('Your account, e-mail, name and password'),
                    item('Your books in ReadIn’s cloud, and every book saved on this phone'),
                    item('Notes, highlights, bookmarks and reading progress'),
                    item('Reading habits, reminders, settings and free trials'),
                    const SizedBox(height: 6),
                    Text(
                      'We keep only payment records without your e-mail (amount, date, plan), because the law requires them for accounting.',
                      style: AppTypography.label(size: 12.5, color: AppColors.textMuted, lineHeight: 18),
                    ),
                    const SizedBox(height: 22),
                    AppTextField(
                      controller: _password,
                      label: 'Your password',
                      isPassword: true,
                      leftIcon: Ionicons.lock_closed_outline,
                      enabled: !_busy,
                      autofillHints: const [AutofillHints.password],
                    ),
                    const SizedBox(height: 14),
                    AppTextField(
                      controller: _confirm,
                      label: 'Type DELETE to confirm',
                      hint: 'DELETE',
                      enabled: !_busy,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: AppTypography.label(size: 13.5, color: AppColors.error400)),
                    ],
                    const SizedBox(height: 22),
                    PressableOpacity(
                      pressedOpacity: 0.85,
                      semanticLabel: 'Delete my account',
                      onTap: _ready ? _delete : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _ready ? AppColors.error500 : AppColors.alpha(AppColors.error500, 0x55),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.white),
                              )
                            : Text(
                                'Delete my account',
                                style: AppTypography.label(size: 16, weight: FontWeight.w700, color: AppColors.white),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Forgot your password? Sign out, use “Forgot password” on the sign-in screen, then come back here. '
                      'You can also delete your account on the web: readin-ehzw.onrender.com/delete-account',
                      style: AppTypography.label(size: 12.5, color: AppColors.textMuted, lineHeight: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
