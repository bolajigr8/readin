import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Rounded rectangle with a dashed outline (RN `borderStyle: 'dashed'`;
/// Android draws dashes of `3 × borderWidth`, i.e. 6 / 6 for a 2 px border).
class DashedRRectBorder extends StatelessWidget {
  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
    this.strokeWidth = 2,
    this.dash = 6,
    this.gap = 6,
    this.fill,
  });

  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
        fill: fill,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  _DashedPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
    required this.fill,
  });

  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(inset, inset, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius - inset),
    );

    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final path = Path()..addRRect(rrect);
    for (final ui.PathMetric metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap ||
      old.fill != fill;
}
