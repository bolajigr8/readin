import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/api/api_result.dart';
import '../../core/services/storage_service.dart';
import '../auth/providers/auth_providers.dart';
import '../habits/habit_alarms.dart';
import '../habits/habit_models.dart';

/// "Delete my account" (S7.1, DECISIONS: everything also leaves the phone).
///
/// 1. The server deletes the account and its data (password re-checked there).
/// 2. Only after the server said yes: this phone is wiped — sign-in tokens, every
///    setting, every book file and cache, scheduled reading reminders — so the
///    app is in the same state as a fresh install.
class AccountDeletion {
  AccountDeletion({
    required ApiClient api,
    required StorageService storage,
    Future<List<Directory>> Function()? localDirs,
    Future<void> Function()? cancelReminders,
  })  : _api = api,
        _storage = storage,
        _localDirs = localDirs ?? _defaultDirs,
        _cancelReminders = cancelReminders ?? (() => HabitAlarms.sync(const HabitData()));

  final ApiClient _api;
  final StorageService _storage;
  final Future<List<Directory>> Function() _localDirs;
  final Future<void> Function() _cancelReminders;

  static Future<List<Directory>> _defaultDirs() async => [
        await getApplicationDocumentsDirectory(), // books, covers, library list, scans
        await getTemporaryDirectory(), // shared quote cards, downloads in progress
      ];

  /// Asks the server to delete the account. Nothing on the phone changes here.
  Future<ApiResult<void>> deleteOnServer(String password) => _api.delete<void>(
        ApiEndpoints.usersMe,
        // `confirm` covers accounts without a password (Google sign-in); the server
        // checks the password whenever the account has one.
        data: {'password': password, 'confirm': 'DELETE'},
        parser: (_) {},
      );

  /// Removes everything ReadIn stored on this phone. Never throws: a file that
  /// cannot be removed must not leave the user half signed-in.
  Future<void> wipeThisPhone() async {
    await _safe('sign-in tokens', _storage.clearSecure);
    await _safe('settings', () async => (await SharedPreferences.getInstance()).clear());
    await _safe('reminders', _cancelReminders);
    final dirs = await _localDirs().catchError((Object _) => <Directory>[]);
    for (final dir in dirs) {
      if (!await dir.exists()) continue;
      await for (final entity in dir.list(followLinks: false)) {
        await _safe('file', () => entity.delete(recursive: true));
      }
    }
  }

  static Future<void> _safe(String what, Future<void> Function() step) async {
    try {
      await step();
    } catch (e) {
      if (kDebugMode) debugPrint('[AccountDeletion] could not clear $what: $e');
    }
  }
}

final accountDeletionProvider = Provider<AccountDeletion>(
  (ref) => AccountDeletion(api: ref.watch(apiClientProvider), storage: ref.watch(storageServiceProvider)),
);
