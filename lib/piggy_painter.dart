import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Рисует стеклянного поросёнка-копилку в ракурсе 3/4 (как на референсе):
/// пятачок сдвинут влево-вниз, оба глаза — сверху-справа от пятачка,
/// уши разной формы (левое — свёрнутое, правое — дугой), хвост не виден,
/// т.к. на этом ракурсе он спрятан за телом.
///
/// Тело и пятачок по-прежнему объединяются в ОДНУ фигуру (Path.combine),
/// поэтому заливка монетками обрезается по общему контуру целиком —
/// это не менялось и продолжает гарантировать, что монеты не выходят
/// за пределы силуэта.
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

    final cx = w * 0.52;
    final cyBody = h * 0.46;
    final rBody = w * 0.34;

    // ---------- Форма тела и пятачка (пятачок смещён влево-вниз) ----------
    final bodyPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cyBody), radius: rBody));

    final snoutCenter = Offset(cx - rBody * 0.42, cyBody + rBody * 0.42);
    final snoutR = rBody * 0.42;
    final snoutPath = Path()
      ..addOval(Rect.fromCircle(center: snoutCenter, radius: snoutR));

    // Объединяем тело и пятачок в одну фигуру — область, где могут быть монеты.
    final silhouette = Path.combine(PathOperation.union, bodyPath, snoutPath);
    final silhouetteBounds = silhouette.getBounds();

    final glassPaint = Paint()..color = glassColor;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = outlineColor;

    // ---------- Ножки ----------
    final legW = rBody * 0.24;
    final legH = rBody * 0.28;
    final legY = cyBody + rBody * 0.66;
    final legXs = [
      cx - rBody * 0.72,
      cx - rBody * 0.24,
      cx + rBody * 0.30,
      cx + rBody * 0.76,
    ];
    for (final lx in legXs) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - legW / 2, legY, legW, legH),
        Radius.circular(legW * 0.4),
      );
      canvas.drawRRect(rrect, glassPaint);
      canvas.drawRRect(rrect, outlinePaint);
    }

    // ---------- Левое ухо — свёрнутое, как загнутая створка ----------
    final earLeft = Path()
      ..moveTo(cx - rBody * 0.32, cyBody - rBody * 0.72)
      ..quadraticBezierTo(
        cx - rBody * 0.66,
        cyBody - rBody * 0.98,
        cx - rBody * 0.58,
        cyBody - rBody * 1.22,
      )
      ..quadraticBezierTo(
        cx - rBody * 0.40,
        cyBody - rBody * 1.10,
        cx - rBody * 0.02,
        cyBody - rBody * 0.80,
      )
      ..close();

    // ---------- Правое ухо — крупная дуга-крючок ----------
    final earRight = Path()
      ..moveTo(cx + rBody * 0.12, cyBody - rBody * 0.78)
      ..quadraticBezierTo(
        cx + rBody * 0.30,
        cyBody - rBody * 1.30,
        cx + rBody * 0.62,
        cyBody - rBody * 1.30,
      )
      ..quadraticBezierTo(
        cx + rBody * 0.64,
        cyBody - rBody * 0.92,
        cx + rBody * 0.42,
        cyBody - rBody * 0.68,
      )
      ..close();

    for (final ear in [earLeft, earRight]) {
      canvas.drawPath(ear, glassPaint);
      canvas.drawPath(ear, outlinePaint);
    }

    // ---------- Заливка монетками — строго внутри объединённого силуэта ----------
    canvas.save();
    canvas.clipPath(silhouette);

    final clampedProgress = progress.clamp(0.0, 1.0);
    final fillHeight = silhouetteBounds.height * clampedProgress;
    final fillTop = silhouetteBounds.bottom - fillHeight;

    if (clampedProgress > 0) {
      canvas.drawRect(
        Rect.fromLTRB(
          silhouetteBounds.left,
          fillTop,
          silhouetteBounds.right,
          silhouetteBounds.bottom,
        ),
        Paint()..color = coinColor.withOpacity(0.20),
      );

      final rnd = math.Random(11);
      final coinR = rBody * 0.115;
      final coinPaint = Paint()..color = coinColor;
      final coinEdgePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = coinColor.withOpacity(0.55);
      final shinePaint = Paint()..color = coinShineColor.withOpacity(0.6);

      double y = silhouetteBounds.bottom - coinR * 0.9;
      while (y > fillTop - coinR) {
        final rowJitter = rnd.nextDouble() * coinR;
        double x = silhouetteBounds.left + rowJitter;
        while (x < silhouetteBounds.right + coinR) {
          final jitterY = (rnd.nextDouble() - 0.5) * coinR * 0.5;
          final center = Offset(x, y + jitterY);
          canvas.drawCircle(center, coinR, coinPaint);
          canvas.drawCircle(center, coinR, coinEdgePaint);
          canvas.drawCircle(
            center.translate(-coinR * 0.3, -coinR * 0.3),
            coinR * 0.32,
            shinePaint,
          );
          x += coinR * 1.9;
        }
        y -= coinR * 1.6;
      }
    }
    canvas.restore();

    // ---------- Стеклянная поверхность поверх монет (единый контур, без шва) ----------
    canvas.drawPath(silhouette, glassPaint);
    canvas.drawPath(silhouette, outlinePaint);

    // ---------- Ободок пятачка ----------
    canvas.drawCircle(
      snoutCenter,
      snoutR * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = outlineColor.withOpacity(0.55),
    );

    // ---------- Ноздри (чуть развёрнуты по диагонали, как на референсе) ----------
    final nostrilPaint = Paint()..color = outlineColor;
    final nostrilRX = snoutR * 0.15;
    final nostrilRY = snoutR * 0.22;
    for (final dir in [-1.0, 1.0]) {
      final center = snoutCenter.translate(dir * snoutR * 0.28, snoutR * 0.02);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(-0.18);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: nostrilRX * 2, height: nostrilRY * 2),
        nostrilPaint,
      );
      canvas.restore();
    }

    // ---------- Глаза — оба сверху-справа от пятачка, близко друг к другу ----------
    final eyePaint = Paint()..color = outlineColor.withOpacity(0.92);
    final eyeShinePaint = Paint()..color = coinShineColor.withOpacity(0.85);

    final eyeCenters = [
      Offset(cx - rBody * 0.06, cyBody - rBody * 0.04),
      Offset(cx + rBody * 0.34, cyBody - rBody * 0.16),
    ];
    final eyeSizes = [
      Offset(rBody * 0.13, rBody * 0.17),
      Offset(rBody * 0.11, rBody * 0.15),
    ];
    for (var i = 0; i < eyeCenters.length; i++) {
      final center = eyeCenters[i];
      final rx = eyeSizes[i].dx;
      final ry = eyeSizes[i].dy;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
        eyePaint,
      );
      canvas.drawCircle(
        center.translate(-rx * 0.3, -ry * 0.4),
        rx * 0.28,
        eyeShinePaint,
      );
    }

    // ---------- Прорезь для монет — диагональная, вдоль наклона головы ----------
    final slotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = outlineColor;
    canvas.drawLine(
      Offset(cx - rBody * 0.16, cyBody - rBody * 0.92),
      Offset(cx + rBody * 0.26, cyBody - rBody * 1.02),
      slotPaint,
    );

    // ---------- Блики стекла — два штриха для более "глянцевого" вида ----------
    final shine1 = Path()
      ..moveTo(cx - rBody * 0.30, cyBody - rBody * 0.60)
      ..quadraticBezierTo(
        cx - rBody * 0.10,
        cyBody - rBody * 0.82,
        cx + rBody * 0.20,
        cyBody - rBody * 0.72,
      );
    final shine2 = Path()
      ..moveTo(cx + rBody * 0.55, cyBody - rBody * 0.10)
      ..quadraticBezierTo(
        cx + rBody * 0.72,
        cyBody + rBody * 0.05,
        cx + rBody * 0.68,
        cyBody + rBody * 0.30,
      );
    final shinePaintStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.26);
    canvas.drawPath(shine1, shinePaintStroke);
    canvas.drawPath(shine2, shinePaintStroke..strokeWidth = 4);
  }

  @override
  bool shouldRepaint(covariant PiggyBankPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
