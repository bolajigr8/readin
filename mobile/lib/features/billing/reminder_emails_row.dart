import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../../constants/app_colors.dart';
import '../../widgets/app_toast.dart';
import '../profile/widgets/settings_row.dart';
import 'billing_providers.dart';

/// Profile → Subscription: "Premium reminder e-mails" on/off (stored on the server, S9.2).
class ReminderEmailsRow extends ConsumerStatefulWidget {
  const ReminderEmailsRow({super.key, this.isLast = true});
  final bool isLast;

  @override
  ConsumerState<ReminderEmailsRow> createState() => _ReminderEmailsRowState();
}

class _ReminderEmailsRowState extends ConsumerState<ReminderEmailsRow> {
  bool? _value; // what the user just chose (shown while the server saves)
  bool _saving = false;

  Future<void> _set(bool on) async {
    if (_saving) return;
    setState(() {
      _value = on;
      _saving = true;
    });
    final res = await ref.read(billingApiProvider).setEmailReminders(on);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.exceptionOrNull != null) {
      setState(() => _value = !on);
      AppToast.error(res.exceptionOrNull!.message);
      return;
    }
    ref.invalidate(billingStatusProvider);
    AppToast.success(on ? 'Reminder e-mails are on.' : 'Reminder e-mails are off.');
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(billingStatusProvider).valueOrNull;
    final value = _value ?? status?.emailReminders ?? true;
    return SettingsRow(
      key: const ValueKey('reminder-emails-row'),
      icon: Ionicons.mail_outline,
      iconColor: AppColors.primary400,
      label: 'Premium reminder e-mails',
      sublabel: 'A short note before Premium ends',
      isLast: widget.isLast,
      rightContent: AppSwitch(value: value, onChanged: status == null ? (_) {} : _set),
    );
  }
}
