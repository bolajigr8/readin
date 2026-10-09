import 'package:flutter/widgets.dart';

/// Detects a plain single-finger tap **without joining the gesture arena**, so
/// it works on top of viewers that own pan/zoom/tap recognisers (pdfrx).
class TapDetector extends StatefulWidget {
  const TapDetector({super.key, required this.onTap, required this.child});

  /// Receives the horizontal position as a fraction of the width (0–1).
  final void Function(double fractionX) onTap;
  final Widget child;

  @override
  State<TapDetector> createState() => _TapDetectorState();
}

class _TapDetectorState extends State<TapDetector> {
  final Map<int, Offset> _down = {};
  final Map<int, DateTime> _downAt = {};
  bool _multi = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        if (_down.isNotEmpty) _multi = true; // pinch / two-finger gesture
        _down[e.pointer] = e.position;
        _downAt[e.pointer] = DateTime.now();
      },
      onPointerUp: (e) {
        final start = _down.remove(e.pointer);
        final at = _downAt.remove(e.pointer);
        final wasMulti = _multi;
        if (_down.isEmpty) _multi = false;
        if (start == null || at == null || wasMulti) return;
        final moved = (e.position - start).distance;
        final quick = DateTime.now().difference(at).inMilliseconds < 350;
        if (moved < 12 && quick) {
          final w = context.size?.width ?? 0;
          widget.onTap(w <= 0 ? 0.5 : (e.localPosition.dx / w).clamp(0.0, 1.0));
        }
      },
      onPointerCancel: (e) {
        _down.remove(e.pointer);
        _downAt.remove(e.pointer);
        if (_down.isEmpty) _multi = false;
      },
      child: widget.child,
    );
  }
}
