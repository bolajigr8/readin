import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Files from other apps, folder scan, "Open with…" and sharing — implemented
/// in `MainActivity.kt`. Every call is a silent no-op where the native side is
/// missing (tests, other platforms).
class NativeFiles {
  NativeFiles._();

  static const MethodChannel _method = MethodChannel('readin/files');
  static const EventChannel _events = EventChannel('readin/incoming');

  static Stream<List<String>>? _incoming;

  /// Files shared to / opened with ReadIn while it is running. Each event is a
  /// list of readable paths (already copied into the app cache).
  static Stream<List<String>> get incoming {
    return _incoming ??= _events
        .receiveBroadcastStream()
        .map<List<String>>(
          (e) => e is List ? e.map((x) => x.toString()).toList() : const <String>[],
        )
        .handleError((Object _) {});
  }

  /// Files that arrived before Dart was listening (cold start via "Share → ReadIn").
  static Future<List<String>> takeIncoming() async {
    try {
      final r = await _method.invokeMethod<List<dynamic>>('takeIncoming');
      return r?.map((x) => x.toString()).toList() ?? const <String>[];
    } on MissingPluginException {
      return const <String>[];
    } catch (_) {
      return const <String>[];
    }
  }

  /// Lets the user choose a folder; returns the supported files inside it
  /// (copied to the app cache). Empty = cancelled / nothing found.
  static Future<List<String>> pickFolder() async {
    try {
      final r = await _method.invokeMethod<List<dynamic>>('pickFolder');
      return r?.map((x) => x.toString()).toList() ?? const <String>[];
    } on MissingPluginException {
      return const <String>[];
    } catch (e) {
      if (kDebugMode) debugPrint('[NativeFiles] pickFolder failed: $e');
      return const <String>[];
    }
  }

  /// "Open with…" — false when no installed app can open the file.
  static Future<bool> openWith(String path, String mime) async {
    try {
      return (await _method.invokeMethod<bool>('openFile', {'path': path, 'mime': mime})) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// System share sheet for a file (e.g. a quote-card PNG).
  static Future<bool> share(String path, String mime, {String? text}) async {
    try {
      return (await _method.invokeMethod<bool>(
            'shareFile',
            {'path': path, 'mime': mime, 'text': text},
          )) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Notification with Previous / Play-Pause / Next / Stop while reading aloud
/// (foreground service → keeps speaking with the screen off).
class ReadAloudNotification {
  ReadAloudNotification._();

  static const MethodChannel _method = MethodChannel('readin/readaloud');
  static const EventChannel _events = EventChannel('readin/readaloud_events');

  static Stream<String>? _stream;
  static String? _owner;

  /// "play" | "pause" | "next" | "prev" | "stop"
  static Stream<String> get actions {
    return _stream ??= _events
        .receiveBroadcastStream()
        .map<String>((e) => e.toString())
        .handleError((Object _) {});
  }

  /// Button presses, only while [owner] is the one that last showed the
  /// notification (the book reader and the listen-preview player share it).
  static Stream<String> actionsFor(String owner) => actions.where((_) => _owner == owner);

  static Future<void> show({
    required String owner,
    required String title,
    required String text,
    required bool playing,
  }) async {
    _owner = owner;
    try {
      await _method.invokeMethod<void>('show', {'title': title, 'text': text, 'playing': playing});
    } on MissingPluginException {
      // not Android
    } catch (e) {
      if (kDebugMode) debugPrint('[ReadAloudNotification] show failed: $e');
    }
  }

  static Future<void> stop({String? owner}) async {
    if (owner != null && _owner != owner) return;
    _owner = null;
    try {
      await _method.invokeMethod<void>('stop');
    } catch (_) {
      // ignore
    }
  }
}
