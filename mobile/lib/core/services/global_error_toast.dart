import '../../widgets/app_toast.dart';
import 'global_error_provider.dart';

/// Turns a [GlobalError] into a toast (context-free).
class GlobalErrorToast {
  const GlobalErrorToast._();

  static void show(GlobalError error) {
    final message = error.message.replaceAll('Exception: ', '');
    final lower = message.toLowerCase();
    if (lower.contains('cancel')) return;
    AppToast.error(message);
  }
}
