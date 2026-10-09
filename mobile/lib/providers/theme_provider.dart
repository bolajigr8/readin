import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences singleton — overridden in `bootstrap()` before runApp.
final sharedPreferencesProvider = Provider<SharedPreferences>((_) {
  throw UnimplementedError('Override in ProviderScope before runApp.');
});

/// ReadIn is dark-only. Kept as a provider so light mode can be added later.
final themeProvider = Provider<ThemeMode>((_) => ThemeMode.dark);
