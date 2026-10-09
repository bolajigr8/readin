import 'package:flutter/widgets.dart';

/// Root navigator key. Used by GoRouter (phase 2) and by [AppToast] to find the
/// root overlay without a BuildContext (RN has a global `toast.*`).
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
