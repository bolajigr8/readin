import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Push notifications are **deferred**: the server stores *Expo* push tokens
/// only, which a Flutter app cannot produce.
///
/// TODO(push): add `firebase_messaging`, send the FCM token to the server
/// (new `fcmToken` field + endpoint server-side) and implement this interface.
abstract class NotificationService {
  /// Called after sign-in when the "Push Notifications" setting is on.
  Future<void> register();

  /// Called on sign-out.
  Future<void> unregister();
}

class NoopNotificationService implements NotificationService {
  const NoopNotificationService();

  @override
  Future<void> register() async {}

  @override
  Future<void> unregister() async {}
}

final notificationServiceProvider =
    Provider<NotificationService>((ref) => const NoopNotificationService());
