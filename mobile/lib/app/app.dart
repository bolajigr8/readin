import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_colors.dart';
import '../core/api/api_endpoints.dart';
import '../core/services/global_error_provider.dart';
import '../core/services/global_error_toast.dart';
import '../core/services/native_bridge.dart';
import '../core/services/router.dart';
import '../core/services/routes.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/library/data/local_import_service.dart';
import '../features/library/providers/import_controller.dart';
import '../features/library/utils/open_book.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';

/// Root widget. Besides the app shell it:
///  * wakes the (free-plan, sleeping) server when the app opens / returns,
///  * imports files that arrive through "Share → ReadIn" / "Open with → ReadIn".
class ReadInApp extends ConsumerStatefulWidget {
  const ReadInApp({super.key});

  @override
  ConsumerState<ReadInApp> createState() => _ReadInAppState();
}

class _ReadInAppState extends ConsumerState<ReadInApp> with WidgetsBindingObserver {
  StreamSubscription<List<String>>? _incomingSub;
  final List<String> _queue = [];
  bool _draining = false;
  DateTime? _lastWake;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingSub = NativeFiles.incoming.listen(_onIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _wakeServer();
      _onIncoming(await NativeFiles.takeIncoming()); // cold start via Share
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _wakeServer();
  }

  /// A free Render server sleeps after 15 min without traffic. One tiny GET when
  /// the app opens starts the wake-up while the cached library is already on
  /// screen, so the user rarely notices. At most once per 8 minutes.
  void _wakeServer() {
    final now = DateTime.now();
    final last = _lastWake;
    if (last != null && now.difference(last).inMinutes < 8) return;
    _lastWake = now;
    unawaited(
      ref.read(apiClientProvider).get<void>(ApiEndpoints.health, parser: (_) {}).then<void>((_) {}),
    );
  }

  void _onIncoming(List<String> paths) {
    if (paths.isEmpty) return;
    _queue.addAll(paths);
    unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_draining || _queue.isEmpty) return;
    if (!ref.read(authProvider).isAuthenticated) return; // retried after sign-in
    _draining = true;
    try {
      while (_queue.isNotEmpty) {
        final batch = List<String>.of(_queue);
        _queue.clear();
        final outcomes = await ref.read(importControllerProvider.notifier).run(batch);
        if (outcomes.isEmpty) continue;
        AppToast.info(ImportController.summarize(outcomes));
        final router = ref.read(routerProvider);
        final single = outcomes.length == 1 ? outcomes.first : null;
        if (single?.book != null) {
          router.go(AppRoutes.libraryTab);
          openBookWith(router, single!.book!);
        } else if (outcomes.any((o) => o.ok || o.status == ImportStatus.duplicate)) {
          router.go(AppRoutes.libraryTab);
        }
      }
    } finally {
      _draining = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Cross-cutting errors (e.g. session expired) → toast.
    ref.listen<GlobalError?>(globalErrorProvider, (previous, next) {
      if (next == null || next == previous) return;
      GlobalErrorToast.show(next);
    });

    // Files that arrived before the user was signed in are imported afterwards.
    ref.listen(authProvider.select((s) => s.isAuthenticated), (prev, next) {
      if (next) unawaited(_drain());
    });

    return MaterialApp.router(
      title: 'ReadIn',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeProvider),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.background,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: MediaQuery(
          // Respect the system font size, but keep layouts intact (0.9–1.2×).
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.of(context).textScaler.clamp(
                  minScaleFactor: 0.9,
                  maxScaleFactor: 1.2,
                ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}
