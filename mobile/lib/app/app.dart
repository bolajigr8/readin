import '../features/billing/billing_providers.dart';
import 'access_refresh.dart';
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
import '../core/formats.dart';
import '../features/features/features_provider.dart';
import '../features/habits/habit_providers.dart';
import '../features/library/data/local_import_service.dart';
import '../features/shelves/shelf_providers.dart';
import '../features/library/providers/library_providers.dart';
import '../features/library/providers/import_controller.dart';
import '../features/library/utils/open_book.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/app_toast.dart';
import '../features/update/update_provider.dart';
import '../features/update/update_widgets.dart';

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
  bool _autoOpened = false;

  // Feature access / plan / payment switch: re-read often so an admin change shows up
  // within about a minute (it used to wait up to 8 minutes, or a sign-out).
  // Timing rules (45 s while open, on resume, max once per 15 s) live in
  // AccessRefreshScheduler so they can be tested.
  late final AccessRefreshScheduler _access = AccessRefreshScheduler(
    isAllowed: () => ref.read(authProvider).isAuthenticated,
    onRefresh: _refreshAccess,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _incomingSub = NativeFiles.incoming.listen(_onIncoming);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _wakeServer();
      unawaited(ref.read(updateProvider.notifier).check()); // S2: newer version? (never blocks when offline)
      _onIncoming(await NativeFiles.takeIncoming()); // cold start via Share
    });
    _access.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _incomingSub?.cancel();
    _access.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _access.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      _wakeServer();
      _access.request(); // right away when the app comes back (at most every 15 s)
      unawaited(ref.read(updateProvider.notifier).check()); // at most every 6 h (always while an update is required)
    }
  }

  /// Light refresh: the user's plan, feature access and the payment switch.
  /// (The heavier shelves / habits pull stays in [_refreshRemote].)
  /// Called by [_access] (signed-in check and 15 s throttle happen there).
  void _refreshAccess() {
    unawaited(() async {
      await ref.read(publicConfigProvider.notifier).refresh();
      await ref.read(refreshUserProvider)();
      await ref.read(featuresProvider.notifier).refresh();
    }());
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
    unawaited(ref.read(publicConfigProvider.notifier).refresh());
    _refreshRemote();
  }

  /// Cold start: continue the book you were reading (once per launch).
  void _tryAutoOpen() {
    if (_autoOpened || !mounted) return;
    if (!ref.read(authProvider).isAuthenticated) return;
    if (!ref.read(storageServiceProvider).openLastBook || _queue.isNotEmpty || _draining) {
      _autoOpened = true; // disabled, or the app was opened to import a shared file
      return;
    }
    final lib = ref.read(libraryProvider);
    if (!lib.hasValue) return; // called again when the library arrives
    _autoOpened = true;
    final book = ref
        .read(continueReadingProvider)
        .where((b) => b.kind == ViewerKind.epub || b.kind == ViewerKind.pdf)
        .firstOrNull;
    if (book == null) return;
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) openBookWith(ref.read(routerProvider), book);
    });
  }

  /// Entitlements (trial / premium), habits and shelves from the server.
  /// Offline or asleep → silently keeps the local copy.
  void _refreshRemote() {
    if (!ref.read(authProvider).isAuthenticated) return;
    unawaited(() async {
      await ref.read(refreshUserProvider)(); // plan + Premium end date from the server
      await ref.read(featuresProvider.notifier).refresh();
      if (!mounted) return;
      await ref.read(shelvesProvider.notifier).pull();
      if (ref.read(habitsAccessProvider).allowed) {
        await ref.read(habitsProvider.notifier).pull();
      }
    }());
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
      if (next) {
        unawaited(_drain());
        _tryAutoOpen();
        _refreshRemote();
      }
    });
    // A DIFFERENT account on this phone must start clean (no data mixing).
    // Signing out and back in as the same person keeps everything (an expired
    // session must never throw away edits that were not uploaded yet).
    ref.listen(authProvider.select((s) => s.user?.id), (prev, next) {
      if (next == null) return;
      final storage = ref.read(storageServiceProvider);
      final last = storage.readString('@readin/last_user_id');
      if (last != null && last.isNotEmpty && last != next) {
        ref.read(featuresProvider.notifier).clear();
        ref.read(habitsProvider.notifier).clearLocal();
        ref.read(shelvesProvider.notifier).clearLocal();
      }
      unawaited(storage.writeString('@readin/last_user_id', next));
    });
    // The library (cached) is ready → continue the last book.
    ref.listen(libraryProvider, (prev, next) {
      if (next.hasValue) _tryAutoOpen();
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
            child: UpdateGate(router: router, child: child ?? const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
