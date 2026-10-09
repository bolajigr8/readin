import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import 'app.dart';

/// Initialises everything the app needs before the first frame and returns
/// the root widget, wrapped in its [ProviderScope].
Future<Widget> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const ReadInApp(),
  );
}
