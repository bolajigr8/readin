import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../constants/app_colors.dart';
import '../features/auth/providers/auth_providers.dart';
import '../providers/drawer_provider.dart';
import '../theme/app_typography.dart';
import '../utils/formatters.dart';
import 'pressable_opacity.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.iconActive);
  final String label;
  final IconData icon;
  final IconData iconActive;
}

const List<_NavItem> _navItems = [
  _NavItem('Home', Ionicons.home_outline, Ionicons.home),
  _NavItem('My Library', Ionicons.library_outline, Ionicons.library),
  _NavItem('Discover', Ionicons.compass_outline, Ionicons.compass),
  _NavItem('Profile', Ionicons.person_outline, Ionicons.person),
];

/// RN `AppDrawer` (UI_SPEC §4.14). Place it in a `Stack` above the tab shell
/// (wrapped in `Positioned.fill`). Open/close with [drawerOpenProvider].
///
/// [activeIndex] is the current tab (0 home · 1 library · 2 discover ·
/// 3 profile); [onNavigate] switches tab.
class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({
    super.key,
    required this.activeIndex,
    required this.onNavigate,
  });

  final int activeIndex;
  final void Function(int index) onNavigate;

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with TickerProviderStateMixin {
  // RN spring (friction 9 / tension 120) converted to physical constants.
  // The overshoot RN has is clamped here (it would reveal a gap at the edge).
  static const SpringDescription _openSpring =
      SpringDescription(mass: 1, stiffness: 520, damping: 28);
  static final SpringDescription _closeSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 1);

  /// 0 = closed, 1 = open (spring driven, unbounded).
  late final AnimationController _slide =
      AnimationController.unbounded(vsync: this, value: 0);
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    reverseDuration: const Duration(milliseconds: 200),
  );

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual<bool>(drawerOpenProvider, (prev, next) {
      next ? _open() : _close();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  void _open() {
    if (!_visible) setState(() => _visible = true);
    _slide.animateWith(SpringSimulation(_openSpring, _slide.value, 1, 0));
    _backdrop.forward();
  }

  Future<void> _close() async {
    final a = _slide.animateWith(
      SpringSimulation(_closeSpring, _slide.value, 0, 0),
    );
    final b = _backdrop.reverse();
    try {
      await Future.wait<void>([a, b]);
    } catch (_) {
      return; // disposed mid-animation
    }
    if (mounted && !ref.read(drawerOpenProvider)) {
      setState(() => _visible = false);
    }
  }

  void _closeDrawer() => ref.read(drawerOpenProvider.notifier).state = false;

  void _navigate(int index) {
    _closeDrawer();
    // RN: closeDrawer(); setTimeout(navigate, 120)
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (mounted) widget.onNavigate(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = ref.watch(drawerOpenProvider);
    if (!_visible) return const SizedBox.shrink();

    final width = math.min(MediaQuery.sizeOf(context).width * 0.82, 320.0);

    return IgnorePointer(
      ignoring: !isOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _closeDrawer,
            child: AnimatedBuilder(
              animation: _backdrop,
              builder: (context, _) => ColoredBox(
                color: Colors.black.withValues(
                  alpha: 0.65 * _backdrop.value.clamp(0.0, 1.0),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _slide,
            builder: (context, child) {
              final p = _slide.value.clamp(0.0, 1.0);
              return Align(
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: Offset(-width * (1 - p), 0),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: _DrawerPanel(
                activeIndex: widget.activeIndex,
                onClose: _closeDrawer,
                onNavigate: _navigate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerPanel extends ConsumerWidget {
  const _DrawerPanel({
    required this.activeIndex,
    required this.onClose,
    required this.onNavigate,
  });

  final int activeIndex;
  final VoidCallback onClose;
  final void Function(int) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final insets = MediaQuery.paddingOf(context);
    final name = user?.displayName ?? 'Reader';
    final isPremium = user?.plan == 'premium';

    return Material(
      color: AppColors.surface,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: AppColors.borderDefault)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20, insets.top + 12, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.alpha(AppColors.primary500, 0x20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.alpha(AppColors.primary500, 0x40),
                          ),
                        ),
                        child: const Icon(
                          Ionicons.book,
                          size: 18,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'ReadIn',
                        style: AppTypography.label(
                          size: 18,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  PressableOpacity(
                    pressedOpacity: 0.75,
                    onTap: onClose,
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.elevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Ionicons.close,
                        size: 22,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // User card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.alpha(AppColors.primary500, 0x25),
                      border: Border.all(
                        color: AppColors.alpha(AppColors.primary500, 0x50),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      userInitials(name),
                      style: AppTypography.label(
                        size: 16,
                        weight: FontWeight.w700,
                        color: AppColors.primary500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            size: 15,
                            weight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            size: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isPremium
                          ? AppColors.alpha(AppColors.amber400, 0x25)
                          : AppColors.borderDefault,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isPremium
                            ? AppColors.alpha(AppColors.amber400, 0x60)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Text(
                      isPremium ? 'PRO' : 'FREE',
                      style: AppTypography.label(
                        size: 10,
                        weight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color:
                            isPremium ? AppColors.amber400 : AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const _Sep(),

            // Nav
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                      child: Text(
                        'MENU',
                        style: AppTypography.label(
                          size: 10,
                          weight: FontWeight.w600,
                          letterSpacing: 1,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _navItems.length; i++)
                      _NavRow(
                        item: _navItems[i],
                        active: i == activeIndex,
                        onTap: () => onNavigate(i),
                      ),
                    if (user?.plan == 'free') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: _Sep(),
                      ),
                      _UpgradeCard(onTap: () => onNavigate(3)),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                math.max(insets.bottom, 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Sep(),
                  const SizedBox(height: 12),
                  PressableOpacity(
                    pressedOpacity: 0.7,
                    onTap: () async {
                      onClose();
                      await ref.read(authProvider.notifier).logout();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Ionicons.log_out_outline,
                            size: 18,
                            color: AppColors.error500,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: AppTypography.label(
                              size: 14,
                              weight: FontWeight.w500,
                              color: AppColors.error500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ReadIn v1.0.0',
                    style: AppTypography.label(
                      size: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 px separator with 20 px horizontal margin (RN `styles.sep`).
class _Sep extends StatelessWidget {
  const _Sep();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(height: 1, color: AppColors.borderDefault),
      );
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final _NavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary500 : AppColors.textSecondary;
    return PressableOpacity(
      pressedOpacity: 0.7,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        color: active ? AppColors.alpha(AppColors.primary500, 0x10) : null,
        child: Stack(
          children: [
            if (active)
              const Positioned(
                left: 0,
                top: 8,
                bottom: 8,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.horizontal(
                      right: Radius.circular(3),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    child: Icon(
                      active ? item.iconActive : item.icon,
                      size: 20,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    item.label,
                    style: AppTypography.label(
                      size: 15,
                      weight: active ? FontWeight.w600 : FontWeight.w400,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableOpacity(
      pressedOpacity: 0.8,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.alpha(AppColors.amber400, 0x10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alpha(AppColors.amber400, 0x30)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.alpha(AppColors.amber400, 0x20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Ionicons.star,
                size: 16,
                color: AppColors.amber400,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium',
                    style: AppTypography.label(
                      size: 13,
                      weight: FontWeight.w600,
                      color: AppColors.amber400,
                    ),
                  ),
                  Text(
                    'Unlimited books & annotations',
                    style: AppTypography.label(
                      size: 11,
                      color: AppColors.alpha(AppColors.amber400, 0x99),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Ionicons.chevron_forward,
              size: 16,
              color: AppColors.amber400,
            ),
          ],
        ),
      ),
    );
  }
}
