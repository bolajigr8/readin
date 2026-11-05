import '../../core/services/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/drawer_provider.dart';
import '../../widgets/app_drawer.dart';
import '../audio/widgets/mini_player.dart';
import 'app_tab_bar.dart';

/// Tab shell: 4 preserved branches + tab bar + drawer overlay.
/// System back closes the drawer first; otherwise default behaviour.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _goTab(BuildContext context, int index) {
    // Drawer extras (not tabs): 4 = Habits, 5 = Notes & Highlights.
    if (index == 4) {
      context.push(AppRoutes.habits);
      return;
    }
    if (index == 5) {
      context.push(AppRoutes.notes);
      return;
    }
    navigationShell.goBranch(
      index,
      // Tapping the active tab again returns to that tab's first screen.
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerOpen = ref.watch(drawerOpenProvider);

    return PopScope(
      canPop: !drawerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(drawerOpenProvider.notifier).state = false;
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            body: navigationShell,
            bottomNavigationBar: AppTabBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (i) => _goTab(context, i),
            ),
          ),
          // Mini player floats above the tab bar, below the drawer.
          MiniPlayer(
            bottomOffset: 56 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          Positioned.fill(
            child: AppDrawer(
              activeIndex: navigationShell.currentIndex,
              onNavigate: (i) => _goTab(context, i),
            ),
          ),
        ],
      ),
    );
  }
}
