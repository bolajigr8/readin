import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/storage_service.dart';
import '../providers/theme_provider.dart';
import 'app.dart';
import 'app_restart.dart';

/// Initialises everything the app needs before the first frame and returns
/// the root widget, wrapped in its [ProviderScope].
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await migrateReaderDefaults(prefs);

  // AppRestart lets "Delete my account" reset every provider (fresh-install state).
  return AppRestart(
    builder: () => ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ReadInApp(),
    ),
  );
}
