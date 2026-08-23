import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Рисует кольцевую диаграмму: один сегмент на категорию,
/// пропорционально сумме трат в этой категории.
class DonutPainter extends CustomPainter {
  final List<MapEntry<Color, double>> segments; // цвет -> сумма
  final double strokeWidth;

  DonutPainter({required this.segments, this.strokeWidth = 26});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<double>(0, (s, e) => s + e.value);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.06);

    // фоновое кольцо
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    if (total <= 0) return;

    double startAngle = -math.pi / 2;
    const gap = 0.035;

    for (final entry in segments) {
      final sweep = (entry.value / total) * math.pi * 2;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..color = entry.key;

      final adjustedSweep = math.max(0.0, sweep - gap);
      canvas.drawArc(rect, startAngle + gap / 2, adjustedSweep, false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}
