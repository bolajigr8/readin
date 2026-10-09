import 'package:flutter_riverpod/flutter_riverpod.dart';

class GlobalError {
  GlobalError(this.message) : timestamp = DateTime.now();

  final String message;
  final DateTime timestamp;
}

/// App-wide error channel. ReadIn only publishes cross-cutting errors here
/// (e.g. "session expired"); screens show their own inline errors.
final globalErrorProvider = StateProvider<GlobalError?>((ref) => null);
