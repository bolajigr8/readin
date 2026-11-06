import 'package:flutter/widgets.dart';

/// Rebuilds everything under it from scratch — including the Riverpod
/// ProviderScope, so every provider forgets its state (used after
/// "Delete my account": the app must look like a fresh install).
class AppRestart extends StatefulWidget {
  const AppRestart({super.key, required this.builder});

  /// Builds the subtree (the ProviderScope + app). Called again on restart.
  final Widget Function() builder;

  static void restart(BuildContext context) =>
      context.findAncestorStateOfType<_AppRestartState>()?._restart();

  @override
  State<AppRestart> createState() => _AppRestartState();
}

class _AppRestartState extends State<AppRestart> {
  Key _key = UniqueKey();

  void _restart() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.builder());
}
