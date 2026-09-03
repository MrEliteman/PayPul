import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Рисует минималистичного "стеклянного" поросёнка-копилку.
/// Чем больше [progress] (0..1), тем выше внутри поднимается
/// уровень золотых монет.
class PiggyBankPainter extends CustomPainter {
  final double progress; // 0..1
  final Color glassColor;
  final Color outlineColor;
  final Color coinColor;
  final Color coinShineColor;

  PiggyBankPainter({
    required this.progress,
    required this.glassColor,
    required this.outlineColor,
    required this.coinColor,
    required this.coinShineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Основное тело — овал, чуть приплюснутый.
    final bodyRect = Rect.fromLTWH(w * 0.08, h * 0.28, w * 0.84, h * 0.56);
    final bodyPath = Path()..addOval(bodyRect);

    // Ушко (треугольник со скруглением) — верх-слева.
    final earPath = Path()
      ..moveTo(w * 0.22, h * 0.30)
      ..lineTo(w * 0.28, h * 0.12)
      ..lineTo(w * 0.40, h * 0.26)
      ..close();

    // Пятачок — кружок справа.
    final snoutCenter = Offset(w * 0.90, h * 0.56);
    final snoutRadius = w * 0.10;

    // Ножки — 4 скруглённых прямоугольника снизу.
    final legWidth = w * 0.08;
    final legHeight = h * 0.12;
    final legY = bodyRect.bottom - h * 0.03;
    final legRects = [
      Rect.fromLTWH(w * 0.18, legY, legWidth, legHeight),
      Rect.fromLTWH(w * 0.34, legY, legWidth, legHeight),
      Rect.fromLTWH(w * 0.56, legY, legWidth, legHeight),
      Rect.fromLTWH(w * 0.72, legY, legWidth, legHeight),
    ];

    // ---------- 1. Стеклянная заливка тела (полупрозрачная) ----------
    final glassPaint = Paint()..color = glassColor;
    canvas.drawPath(bodyPath, glassPaint);

    // ---------- 2. Монеты — заливаются снизу вверх по прогрессу ----------
    canvas.save();
    canvas.clipPath(bodyPath);

    final fillHeight = bodyRect.height * progress.clamp(0.0, 1.0);
    final fillRect = Rect.fromLTWH(
      bodyRect.left,
      bodyRect.bottom - fillHeight,
      bodyRect.width,
      fillHeight,
    );

    if (progress > 0) {
      // мягкая золотая подложка
      canvas.drawRect(fillRect, Paint()..color = coinColor.withOpacity(0.18));

      // "монеты" — сетка кружков со случайным, но детерминированным смещением
      final rnd = math.Random(7);
      const coinR = 6.5;
      final coinPaint = Paint()..color = coinColor;
      final shinePaint = Paint()..color = coinShineColor.withOpacity(0.55);

      double y = bodyRect.bottom - coinR;
      while (y > fillRect.top - coinR) {
        final rowOffset = rnd.nextDouble() * coinR;
        double x = bodyRect.left + rowOffset;
        while (x < bodyRect.right + coinR) {
          final jitterY = (rnd.nextDouble() - 0.5) * 3;
          final center = Offset(x, y + jitterY);
          canvas.drawCircle(center, coinR, coinPaint);
          canvas.drawCircle(
            center.translate(-coinR * 0.25, -coinR * 0.25),
            coinR * 0.35,
            shinePaint,
          );
          x += coinR * 2 - 1.5;
        }
        y -= coinR * 1.7;
      }
    }
    canvas.restore();

    // ---------- 3. Контур тела поверх всего ----------
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = outlineColor;
    canvas.drawPath(bodyPath, outlinePaint);

    // ушко
    canvas.drawPath(earPath, glassPaint);
    canvas.drawPath(
      earPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = outlineColor
        ..strokeJoin = StrokeJoin.round,
    );

    // пятачок
    canvas.drawCircle(snoutCenter, snoutRadius, glassPaint);
    canvas.drawCircle(snoutCenter, snoutRadius, outlinePaint..strokeWidth = 2.5);
    // ноздри
    final nostrilPaint = Paint()..color = outlineColor;
    canvas.drawCircle(snoutCenter.translate(-snoutRadius * 0.35, 0), 2.2, nostrilPaint);
    canvas.drawCircle(snoutCenter.translate(snoutRadius * 0.35, 0), 2.2, nostrilPaint);

    // ножки
    final legPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = outlineColor;
    for (final leg in legRects) {
      final rrect = RRect.fromRectAndRadius(leg, const Radius.circular(6));
      canvas.drawRRect(rrect, glassPaint);
      canvas.drawRRect(rrect, legPaint);
    }

    // прорезь для монет сверху
    final slotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = outlineColor;
    canvas.drawLine(
      Offset(w * 0.46, h * 0.30),
      Offset(w * 0.58, h * 0.30),
      slotPaint,
    );

    // хвостик-завиток
    final tailPath = Path()
      ..moveTo(w * 0.10, h * 0.42)
      ..cubicTo(w * 0.02, h * 0.38, w * 0.02, h * 0.30, w * 0.09, h * 0.30);
    canvas.drawPath(
      tailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..color = outlineColor,
    );

    // лёгкий блик "стекла" сверху-слева тела
    final shinePath = Path()
      ..moveTo(bodyRect.left + bodyRect.width * 0.22, bodyRect.top + bodyRect.height * 0.22)
      ..quadraticBezierTo(
        bodyRect.left + bodyRect.width * 0.30,
        bodyRect.top + bodyRect.height * 0.08,
        bodyRect.left + bodyRect.width * 0.44,
        bodyRect.top + bodyRect.height * 0.14,
      );
    canvas.drawPath(
      shinePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.25),
    );
  }

  @override
  bool shouldRepaint(covariant PiggyBankPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
