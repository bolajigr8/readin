import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum VolumeKey { up, down }

/// Android hardware volume buttons as page-turn input.
///
/// While [enable]d, MainActivity consumes the volume keys (no system volume UI)
/// and forwards them here; [disable] gives them back to the system. The native
/// part lives in `android/.../MainActivity.kt` (MethodChannel `readin/volume`,
/// EventChannel `readin/volume_events`). On other platforms / when the channel
/// is missing everything is a silent no-op.
class VolumeKeys {
  VolumeKeys._();

  static const MethodChannel _method = MethodChannel('readin/volume');
  static const EventChannel _events = EventChannel('readin/volume_events');

  static Stream<VolumeKey>? _stream;

  /// Stream of presses (broadcast). Safe to listen to even if unsupported.
  static Stream<VolumeKey> get presses {
    return _stream ??= _events.receiveBroadcastStream().map<VolumeKey?>((e) {
      if (e == 'up') return VolumeKey.up;
      if (e == 'down') return VolumeKey.down;
      return null;
    }).where((k) => k != null).cast<VolumeKey>().handleError((Object _) {});
  }

  static Future<void> enable() => _call('enable');
  static Future<void> disable() => _call('disable');

  static Future<void> _call(String name) async {
    try {
      await _method.invokeMethod<void>(name);
    } on MissingPluginException {
      // not Android / old native code: nothing to do
    } catch (e) {
      if (kDebugMode) debugPrint('[VolumeKeys] $name failed: $e');
    }
  }
}
