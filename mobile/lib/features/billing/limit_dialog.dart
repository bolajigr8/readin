import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/confirm_dialog.dart';
import 'billing_providers.dart';

/// "Limit reached" prompt. It only offers **Upgrade** when the admin has payments
/// switched on; otherwise it is a plain message. Returns true when the user
/// chose to upgrade.
Future<bool> showLimitDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String message,
}) async {
  if (!ref.read(billingVisibleProvider)) {
    await showAlertDialog(context, title: title, message: message);
    return false;
  }
  return showConfirmDialog(
    context,
    title: title,
    message: message,
    confirmLabel: 'Upgrade',
    cancelLabel: 'Not now',
  );
}
