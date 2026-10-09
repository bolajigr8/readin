import 'package:flutter/material.dart';

/// Drives RN `Animated.stagger(80, …)`: [count] groups, each fading in and
/// sliding up 24 px over 420 ms, started 80 ms apart.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.children});

  final List<Widget> children;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const int _durationMs = 420;
  static const int _staggerMs = 80;

  late final AnimationController _c;

  int get _totalMs => _durationMs + _staggerMs * (widget.children.length - 1);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _totalMs),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _animFor(int i) {
    final start = (_staggerMs * i) / _totalMs;
    final end = (_staggerMs * i + _durationMs) / _totalMs;
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeInOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    final out = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      if (i > 0) out.add(const SizedBox(height: 32));
      final a = _animFor(i);
      out.add(
        AnimatedBuilder(
          animation: a,
          builder: (context, child) => Opacity(
            opacity: a.value,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - a.value)),
              child: child,
            ),
          ),
          child: widget.children[i],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: out,
    );
  }
}
