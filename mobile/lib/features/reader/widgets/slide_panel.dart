import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../constants/app_colors.dart';

enum PanelEdge { left, bottom }

/// Overlay panel with the RN animation: spring slide + backdrop fade
/// (backdrop 200 ms in / 180 ms out, max opacity [backdropOpacity]).
/// Mounted only while open or animating, like the RN components.
///
/// The spring is RN's friction 9 / tension 120 (stiffness 520, damping 28);
/// overshoot is clamped so no gap appears at the screen edge.
class SlidePanel extends StatefulWidget {
  const SlidePanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.edge,
    required this.child,
    this.size,
    this.backdropOpacity = 0.6,
    this.showBackdrop = true,
    this.slideDistance = 300,
  });

  final bool isOpen;
  final VoidCallback onClose;
  final PanelEdge edge;

  /// Width for [PanelEdge.left]; ignored for bottom panels (full width).
  final double? size;
  final double backdropOpacity;
  final bool showBackdrop;

  /// How far below the screen the bottom panel starts (RN: 300 / 500).
  final double slideDistance;
  final Widget child;

  @override
  State<SlidePanel> createState() => _SlidePanelState();
}

class _SlidePanelState extends State<SlidePanel> with TickerProviderStateMixin {
  static const SpringDescription _spring =
      SpringDescription(mass: 1, stiffness: 520, damping: 28);

  late final AnimationController _slide =
      AnimationController.unbounded(vsync: this, value: 0);
  late final AnimationController _backdrop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 180),
  );
  bool _mounted = false;

  @override
  void initState() {
    super.initState();
    if (widget.isOpen) _open();
  }

  @override
  void didUpdateWidget(SlidePanel old) {
    super.didUpdateWidget(old);
    if (widget.isOpen != old.isOpen) {
      widget.isOpen ? _open() : _close();
    }
  }

  @override
  void dispose() {
    _slide.dispose();
    _backdrop.dispose();
    super.dispose();
  }

  void _open() {
    if (!_mounted) _mounted = true;
    _slide.animateWith(SpringSimulation(_spring, _slide.value, 1, 0));
    _backdrop.forward();
    if (mounted) setState(() {});
  }

  Future<void> _close() async {
    final a = _slide.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 520, ratio: 1),
        _slide.value,
        0,
        0,
      ),
    );
    final b = _backdrop.reverse();
    try {
      await Future.wait<void>([a, b]);
    } catch (_) {
      return;
    }
    if (mounted && !widget.isOpen) setState(() => _mounted = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);

    return IgnorePointer(
      ignoring: !widget.isOpen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showBackdrop)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onClose,
              child: AnimatedBuilder(
                animation: _backdrop,
                builder: (context, _) => ColoredBox(
                  color: AppColors.black.withValues(
                    alpha: widget.backdropOpacity * _backdrop.value.clamp(0.0, 1.0),
                  ),
                ),
              ),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onClose,
            ),
          AnimatedBuilder(
            animation: _slide,
            builder: (context, child) {
              final p = _slide.value.clamp(0.0, 1.0);
              if (widget.edge == PanelEdge.left) {
                final w = widget.size ?? 300;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Transform.translate(
                    offset: Offset(-w * (1 - p), 0),
                    child: SizedBox(width: w, height: double.infinity, child: child),
                  ),
                );
              }
              // Bottom sheet: slides up from 300 px below (RN translateY 300).
              return Align(
                alignment: Alignment.bottomCenter,
                child: Transform.translate(
                  offset: Offset(0, widget.slideDistance * (1 - p)),
                  child: SizedBox(width: screen.width, child: child),
                ),
              );
            },
            child: Material(type: MaterialType.transparency, child: widget.child),
          ),
        ],
      ),
    );
  }
}
