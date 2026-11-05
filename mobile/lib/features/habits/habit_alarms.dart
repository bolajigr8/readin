import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'habit_models.dart';

/// Reminders live in native Android code (AlarmManager + notification with a
/// Snooze button), so they fire even when the app is closed and survive reboots.
/// Dart only hands over the schedule — and, for the evening nudge, which habits
/// are already done today.
class HabitAlarms {
  HabitAlarms._();

  static const MethodChannel _channel = MethodChannel('readin/habits');

  /// Replaces all scheduled reminders with those of [data].
  static Future<void> sync(HabitData data, {DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    final key = habitDayKey(today);
    final list = <Map<String, dynamic>>[];
    for (final h in data.habits) {
      final log = data.log[h.id] ?? const <String, DayLog>{};
      final done = statusOn(h, log[key], today, today) == DayStatus.done;
      list.add({
        'id': h.id,
        'name': h.name,
        'goal': h.goal,
        'unit': h.unit.name,
        'days': h.days.toList()..sort(),
        'reminder': h.reminderMinutes,
        'nudge': h.nudge,
        'doneDate': done ? key : '',
        'streak': currentStreak(h, log, today),
      });
    }
    try {
      await _channel.invokeMethod<void>('sync', jsonEncode(list));
    } on MissingPluginException {
      // not Android
    } catch (e) {
      if (kDebugMode) debugPrint('[HabitAlarms] sync failed: $e');
    }
  }

  /// Asks for the notification permission (Android 13+).
  static Future<void> askPermission() async {
    try {
      await _channel.invokeMethod<void>('askPermission');
    } catch (_) {}
  }
}
