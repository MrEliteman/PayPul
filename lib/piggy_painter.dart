import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Рисует круглого стеклянного поросёнка-копилку.
/// Тело и пятачок объединяются в ОДНУ фигуру (Path.combine), поэтому
/// заливка монетками обрезается по этому объединённому контуру целиком —
/// монеты физически не могут оказаться за пределами силуэта поросёнка,
/// и на стыке тела с пятачком не остаётся шва от двух отдельных обводок.
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

    final cx = w * 0.5;
    final cyBody = h * 0.46;
    final rBody = w * 0.34;

    // ---------- Форма тела и пятачка ----------
    final bodyPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cyBody), radius: rBody));

    final snoutCenter = Offset(cx, cyBody + rBody * 0.62);
    final snoutR = rBody * 0.40;
    final snoutPath = Path()
      ..addOval(Rect.fromCircle(center: snoutCenter, radius: snoutR));

    // Объединяем тело и пятачок в одну фигуру — это и есть "область копилки",
    // внутри которой могут находиться монеты, и у неё один цельный контур.
    final silhouette = Path.combine(PathOperation.union, bodyPath, snoutPath);
    final silhouetteBounds = silhouette.getBounds();

    final glassPaint = Paint()..color = glassColor;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round
      ..color = outlineColor;

    // ---------- Ножки (рисуются первыми, будто выглядывают из-под тела) ----------
    final legW = rBody * 0.24;
    final legH = rBody * 0.30;
    final legY = cyBody + rBody * 0.62;
    final legXs = [
      cx - rBody * 0.78,
      cx - rBody * 0.30,
      cx + rBody * 0.30,
      cx + rBody * 0.78,
    ];
    for (final lx in legXs) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(lx - legW / 2, legY, legW, legH),
        Radius.circular(legW * 0.4),
      );
      canvas.drawRRect(rrect, glassPaint);
      canvas.drawRRect(rrect, outlinePaint);
    }

    // ---------- Уши ----------
    Path earPath(bool left) {
      final dir = left ? -1.0 : 1.0;
      final baseX = cx + dir * rBody * 0.55;
      final baseY = cyBody - rBody * 0.62;
      final tipX = cx + dir * rBody * 0.92;
      final tipY = cyBody - rBody * 1.18;
      final path = Path()..moveTo(baseX, baseY);
      path.quadraticBezierTo(
        cx + dir * rBody * 0.55,
        cyBody - rBody * 1.05,
        tipX,
        tipY,
      );
      path.quadraticBezierTo(
        cx + dir * rBody * 1.05,
        cyBody - rBody * 0.75,
        cx + dir * rBody * 0.30,
        cyBody - rBody * 0.55,
      );
      path.close();
      return path;
    }

    final earLeft = earPath(true);
    final earRight = earPath(false);
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
      // мягкая золотая подложка под монетками
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
      snoutR * 0.82,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = outlineColor.withOpacity(0.55),
    );

    // ---------- Ноздри ----------
    final nostrilPaint = Paint()..color = outlineColor;
    final nostrilRX = snoutR * 0.16;
    final nostrilRY = snoutR * 0.22;
    for (final dir in [-1.0, 1.0]) {
      final center = snoutCenter.translate(dir * snoutR * 0.30, 0);
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: nostrilRX * 2, height: nostrilRY * 2),
        nostrilPaint,
      );
      canvas.restore();
    }

    // ---------- Глаза ----------
    final eyeY = cyBody - rBody * 0.08;
    final eyeRX = rBody * 0.12;
    final eyeRY = rBody * 0.16;
    final eyePaint = Paint()..color = outlineColor.withOpacity(0.92);
    final eyeShinePaint = Paint()..color = coinShineColor.withOpacity(0.85);
    for (final dir in [-1.0, 1.0]) {
      final center = Offset(cx + dir * rBody * 0.34, eyeY);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: eyeRX * 2, height: eyeRY * 2),
        eyePaint,
      );
      canvas.drawCircle(
        center.translate(-eyeRX * 0.3, -eyeRY * 0.4),
        eyeRX * 0.28,
        eyeShinePaint,
      );
    }

    // ---------- Прорезь для монет ----------
    final slotPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..color = outlineColor;
    final slotY = cyBody - rBody * 0.92;
    canvas.drawLine(
      Offset(cx - rBody * 0.22, slotY),
      Offset(cx + rBody * 0.22, slotY),
      slotPaint,
    );

    // ---------- Хвостик ----------
    final tailPath = Path()
      ..moveTo(cx + rBody * 0.95, cyBody + rBody * 0.05)
      ..cubicTo(
        cx + rBody * 1.25,
        cyBody - rBody * 0.05,
        cx + rBody * 1.20,
        cyBody + rBody * 0.35,
        cx + rBody * 0.98,
        cyBody + rBody * 0.30,
      );
    canvas.drawPath(
      tailPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = outlineColor,
    );

    // ---------- Блик стекла на теле ----------
    final shinePath = Path()
      ..moveTo(cx - rBody * 0.55, cyBody - rBody * 0.55)
      ..quadraticBezierTo(
        cx - rBody * 0.42,
        cyBody - rBody * 0.78,
        cx - rBody * 0.15,
        cyBody - rBody * 0.68,
      );
    canvas.drawPath(
      shinePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.28),
    );
  }

  @override
  bool shouldRepaint(covariant PiggyBankPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
