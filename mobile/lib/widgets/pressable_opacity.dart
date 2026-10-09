import 'package:flutter/widgets.dart';

/// RN `TouchableOpacity`: dims while pressed, no Material ripple.
class PressableOpacity extends StatefulWidget {
  const PressableOpacity({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedOpacity = 0.75,
    this.behavior = HitTestBehavior.opaque,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedOpacity;
  final HitTestBehavior behavior;

  /// Accessibility label (TalkBack). Set it on every icon-only button.
  final String? semanticLabel;

  @override
  State<PressableOpacity> createState() => _PressableOpacityState();
}

class _PressableOpacityState extends State<PressableOpacity> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final detector = GestureDetector(
      behavior: widget.behavior,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedOpacity(
        opacity: _pressed ? widget.pressedOpacity : 1,
        duration: const Duration(milliseconds: 80),
        child: widget.child,
      ),
    );
    if (widget.semanticLabel == null) return detector;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: detector,
    );
  }
}
