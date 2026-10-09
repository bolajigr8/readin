import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readin_flutter/constants/ionicons.dart';

import '../constants/app_colors.dart';
import '../core/services/navigator_keys.dart';
import '../theme/app_typography.dart';

enum ToastType { success, error, warning, info }

class _ToastData {
  _ToastData(this.id, this.message, this.type);
  final int id;
  final String message;
  final ToastType type;
}

/// Global toast (RN `toast.success/error/warning/info`). No BuildContext
/// needed: it inserts into the root navigator's overlay.
///
/// Spec: top (safe area + 12), left/right 16, max 3 stacked, auto-dismiss
/// 3500 ms, slide from -80 + fade 200 ms.
class AppToast {
  AppToast._();

  static final ValueNotifier<List<_ToastData>> _items =
      ValueNotifier<List<_ToastData>>(<_ToastData>[]);
  static OverlayEntry? _entry;
  static int _seq = 0;

  static void success(String message) => show(message, ToastType.success);
  static void error(String message) => show(message, ToastType.error);
  static void warning(String message) => show(message, ToastType.warning);
  static void info(String message) => show(message, ToastType.info);

  static void show(String message, [ToastType type = ToastType.info]) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    var list = <_ToastData>[..._items.value, _ToastData(_seq++, message, type)];
    if (list.length > 3) list = list.sublist(list.length - 3);
    _items.value = list;

    if (_entry == null) {
      _entry = OverlayEntry(builder: (_) => const _ToastLayer());
      overlay.insert(_entry!);
    }
  }

  static void _remove(int id) {
    _items.value = _items.value.where((t) => t.id != id).toList();
    if (_items.value.isEmpty) {
      _entry?.remove();
      _entry?.dispose();
      _entry = null;
    }
  }
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<_ToastData>>(
      valueListenable: AppToast._items,
      builder: (context, items, _) {
        final top = MediaQuery.of(context).padding.top + 12;
        return Positioned(
          top: top,
          left: 16,
          right: 16,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ToastBanner(
                      key: ValueKey<int>(item.id),
                      data: item,
                      onDismissed: AppToast._remove,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ToastBanner extends StatefulWidget {
  const _ToastBanner({super.key, required this.data, required this.onDismissed});

  final _ToastData data;
  final void Function(int id) onDismissed;

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner>
    with SingleTickerProviderStateMixin {
  // RN: spring (friction 8 / tension 120) for the slide, 200 ms timing for
  // opacity; 200 ms linear for both when dismissing.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _slide = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
    reverseCurve: Curves.linear,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 200 / 350, curve: Curves.linear),
    reverseCurve: Curves.linear,
  );
  Timer? _timer;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(milliseconds: 3500), _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    _timer?.cancel();
    try {
      await _c.reverse();
    } catch (_) {
      // Controller disposed mid-animation; nothing to do.
    }
    widget.onDismissed(widget.data.id);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  (Color, IconData) get _style => switch (widget.data.type) {
        ToastType.success => (
            AppColors.success500,
            Ionicons.checkmark_circle_outline,
          ),
        ToastType.error => (
            AppColors.error500,
            Ionicons.alert_circle_outline,
          ),
        ToastType.warning => (AppColors.warning500, Ionicons.warning_outline),
        ToastType.info => (
            AppColors.primary500,
            Ionicons.information_circle_outline,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, -80 * (1 - _slide.value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.alpha(color, 0x18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.alpha(color, 0x40)),
          // RN: shadow #000 / .3 / offset 0,4 / radius 8
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.data.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.label(size: 14, lineHeight: 20),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const Icon(
                Ionicons.close,
                size: 15,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
