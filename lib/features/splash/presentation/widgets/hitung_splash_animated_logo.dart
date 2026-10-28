import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Widget animasi logo resmi "hitung." khusus tampilan Fresh Start / Splash Screen.
///
/// Menggunakan native Canvas & physics-based spring interpolation:
/// 1. Squircle Base: Pop-in dengan elastic spring scale (0.0 -> 1.08 -> 1.0) & soft lime glow.
/// 2. Huruf 'h' Minimalis: Tergambar presisi dengan rounded cap dan black #111111.
/// 3. Titik Ungu (Purple Dot): Jatuh dari atas, memantul dengan squash & stretch,
///    lalu memancarkan purple shockwave ripple ring saat mendarat.
/// 4. Shimmer Sheen: Kilauan cahaya melintas lembut secara diagonal di atas logo.
class HitungSplashAnimatedLogo extends StatelessWidget {
  final double size;
  final double progress; // 0.0 to 1.0
  final bool reduceMotion;

  const HitungSplashAnimatedLogo({
    super.key,
    this.size = 110,
    required this.progress,
    this.reduceMotion = false,
  });

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) {
      // Tampilan statis jika pengguna mengaktifkan reduce motion
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.neonLime,
          borderRadius: BorderRadius.circular(size * 0.28),
          boxShadow: [
            BoxShadow(
              color: AppColors.neonLime.withOpacity(0.3),
              blurRadius: size * 0.25,
              offset: Offset(0, size * 0.08),
            ),
          ],
        ),
        child: CustomPaint(
          size: Size(size, size),
          painter: _StaticHPainter(
            hColor: AppColors.brandDark,
            dotColor: AppColors.brandPurple,
          ),
        ),
      );
    }

    return CustomPaint(
      size: Size(size, size),
      painter: _SplashLogoPainter(
        progress: progress,
        hColor: AppColors.brandDark,
        dotColor: AppColors.brandPurple,
        limeColor: AppColors.neonLime,
      ),
    );
  }
}

class _SplashLogoPainter extends CustomPainter {
  final double progress;
  final Color hColor;
  final Color dotColor;
  final Color limeColor;

  _SplashLogoPainter({
    required this.progress,
    required this.hColor,
    required this.dotColor,
    required this.limeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // ----------------------------------------------------
    // FASE 1: Base Squircle Entrance (progress: 0.0 -> 0.35)
    // ----------------------------------------------------
    final baseProgress = (progress / 0.35).clamp(0.0, 1.0);
    if (baseProgress <= 0.0) return;

    // Elastic spring curve formula
    final baseScale = _elasticOut(baseProgress);
    final baseOpacity = (progress / 0.15).clamp(0.0, 1.0);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(baseScale);
    canvas.translate(-center.dx, -center.dy);

    final squircleRect = Rect.fromLTWH(0, 0, w, h);
    final squircleRRect = RRect.fromRectAndRadius(
      squircleRect,
      Radius.circular(w * 0.28),
    );

    // 1. Neon Glow Shadow
    final shadowPaint = Paint()
      ..color = limeColor.withOpacity(0.35 * baseOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.22);
    canvas.drawRRect(
      squircleRRect.shift(Offset(0, h * 0.08)),
      shadowPaint,
    );

    // 2. Base Squircle Fill dengan gradient halus
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFFD9FF43),
        limeColor,
      ],
    );
    final basePaint = Paint()
      ..shader = baseGradient.createShader(squircleRect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(squircleRRect, basePaint);

    // ----------------------------------------------------
    // FASE 2: Huruf 'h' Minimalis (progress: 0.12 -> 0.38)
    // ----------------------------------------------------
    final hProgress = ((progress - 0.12) / 0.26).clamp(0.0, 1.0);
    if (hProgress > 0.0) {
      final hScale = _easeOutBack(hProgress);
      final hAlpha = (hProgress * 1.5).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(hScale);
      canvas.translate(-center.dx, -center.dy);

      final strokeWidth = w * 0.17;
      final hPaint = Paint()
        ..color = hColor.withOpacity(hAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final stemX = w * 0.33;
      final stemTop = h * 0.22;
      final stemBottom = h * 0.78;
      final rightLegX = w * 0.63;
      final archTopY = h * 0.38;
      final archBranchY = h * 0.48;

      // Tiang kiri huruf 'h'
      canvas.drawLine(
        Offset(stemX, stemTop),
        Offset(stemX, stemBottom),
        hPaint,
      );

      // Lengkungan bahu dan kaki kanan huruf 'h'
      final archPath = Path();
      archPath.moveTo(stemX, archBranchY);
      archPath.cubicTo(
        stemX + (rightLegX - stemX) * 0.15,
        archTopY,
        rightLegX - (rightLegX - stemX) * 0.15,
        archTopY,
        rightLegX,
        archTopY + (stemBottom - archTopY) * 0.35,
      );
      archPath.lineTo(rightLegX, stemBottom);
      canvas.drawPath(archPath, hPaint);

      canvas.restore();
    }

    // ----------------------------------------------------
    // FASE 3: Shimmer Sheen Melintas (progress: 0.65 -> 0.85)
    // ----------------------------------------------------
    final shimmerProgress = ((progress - 0.65) / 0.20).clamp(0.0, 1.0);
    if (shimmerProgress > 0.0 && shimmerProgress < 1.0) {
      canvas.save();
      canvas.clipRRect(squircleRRect);

      final shimmerX = -w * 0.6 + shimmerProgress * (w * 2.2);
      final shimmerPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(shimmerX - 30, 0),
          Offset(shimmerX + 30, h),
          [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.38),
            Colors.white.withOpacity(0.0),
          ],
          [0.0, 0.5, 1.0],
        );

      canvas.drawPaint(shimmerPaint);
      canvas.restore();
    }

    // ----------------------------------------------------
    // FASE 4: Titik Ungu Memantul (progress: 0.30 -> 0.62)
    // ----------------------------------------------------
    final dotTargetX = w * 0.81;
    final dotTargetY = h * 0.71;
    final dotRadius = w * 0.082;

    if (progress >= 0.30) {
      double dotY = dotTargetY;
      double scaleX = 1.0;
      double scaleY = 1.0;
      double dotAlpha = 1.0;

      if (progress < 0.44) {
        // Jatuh dari atas dengan percepatan gravitasi (easeIn)
        final dropT = (progress - 0.30) / 0.14;
        final dropEased = dropT * dropT; // easeInQuad
        dotY = ui.lerpDouble(dotTargetY - h * 0.55, dotTargetY, dropEased)!;
        dotAlpha = (dropT * 2.0).clamp(0.0, 1.0);
        // Sedikit memanjang saat jatuh
        scaleX = 0.88;
        scaleY = 1.12;
      } else if (progress < 0.49) {
        // Impact! Squash & stretch pada saat mendarat
        final impactT = (progress - 0.44) / 0.05;
        scaleX = ui.lerpDouble(1.35, 1.0, impactT)!;
        scaleY = ui.lerpDouble(0.70, 1.0, impactT)!;
        dotY = dotTargetY + (1.0 - scaleY) * dotRadius;
      } else if (progress < 0.56) {
        // Rebound pantulan kecil
        final bounceT = (progress - 0.49) / 0.07;
        final bounceH = math.sin(bounceT * math.pi) * (h * 0.09);
        dotY = dotTargetY - bounceH;
        scaleX = ui.lerpDouble(0.92, 1.0, bounceT)!;
        scaleY = ui.lerpDouble(1.08, 1.0, bounceT)!;
      } else {
        // Settle di posisi akhir
        dotY = dotTargetY;
        scaleX = 1.0;
        scaleY = 1.0;
      }

      // Shockwave ripple ring saat mendarat (progress: 0.44 -> 0.60)
      if (progress >= 0.44 && progress <= 0.60) {
        final rippleT = (progress - 0.44) / 0.16;
        final rippleRadius = dotRadius + rippleT * (w * 0.26);
        final rippleAlpha = (1.0 - rippleT) * 0.7;

        final ripplePaint = Paint()
          ..color = dotColor.withOpacity(rippleAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.8, (1.0 - rippleT) * 2.5);

        canvas.drawCircle(Offset(dotTargetX, dotTargetY), rippleRadius, ripplePaint);
      }

      // Gambar titik ungu dengan squash & stretch matrix
      canvas.save();
      canvas.translate(dotTargetX, dotY);
      canvas.scale(scaleX, scaleY);

      // Titik Ungu Fill + subtle aura
      final dotPaint = Paint()
        ..color = dotColor.withOpacity(dotAlpha)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset.zero, dotRadius, dotPaint);

      // Aksen titik kilau kecil di dalam titik ungu
      final dotGlossPaint = Paint()
        ..color = Colors.white.withOpacity(0.45 * dotAlpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(-dotRadius * 0.3, -dotRadius * 0.3), dotRadius * 0.28, dotGlossPaint);

      canvas.restore();
    }

    canvas.restore(); // Restore squircle transform
  }

  // Elastic Out Easing
  double _elasticOut(double t) {
    if (t == 0.0) return 0.0;
    if (t == 1.0) return 1.0;
    const p = 0.38;
    return math.pow(2.0, -10.0 * t) * math.sin((t - p / 4.0) * (2.0 * math.pi) / p) + 1.0;
  }

  // Ease Out Back Easing
  double _easeOutBack(double t) {
    const s = 1.70158;
    final t1 = t - 1.0;
    return t1 * t1 * ((s + 1.0) * t1 + s) + 1.0;
  }

  @override
  bool shouldRepaint(covariant _SplashLogoPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.hColor != hColor ||
        oldDelegate.dotColor != dotColor ||
        oldDelegate.limeColor != limeColor;
  }
}

class _StaticHPainter extends CustomPainter {
  final Color hColor;
  final Color dotColor;

  _StaticHPainter({required this.hColor, required this.dotColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.17;

    final hPaint = Paint()
      ..color = hColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final stemX = w * 0.33;
    final stemTop = h * 0.22;
    final stemBottom = h * 0.78;
    final rightLegX = w * 0.63;
    final archTopY = h * 0.38;
    final archBranchY = h * 0.48;

    canvas.drawLine(Offset(stemX, stemTop), Offset(stemX, stemBottom), hPaint);

    final archPath = Path();
    archPath.moveTo(stemX, archBranchY);
    archPath.cubicTo(
      stemX + (rightLegX - stemX) * 0.15,
      archTopY,
      rightLegX - (rightLegX - stemX) * 0.15,
      archTopY,
      rightLegX,
      archTopY + (stemBottom - archTopY) * 0.35,
    );
    archPath.lineTo(rightLegX, stemBottom);
    canvas.drawPath(archPath, hPaint);

    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.81, h * 0.71), w * 0.082, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _StaticHPainter oldDelegate) => false;
}
