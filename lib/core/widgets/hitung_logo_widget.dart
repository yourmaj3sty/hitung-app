import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

enum HitungLogoVariant {
  lime,   // Default: Neon Lime base (#CEFD37), Black 'h', Purple dot (#7C3AED)
  purple, // Purple base (#7C3AED), Neon Lime 'h', White dot
  dark,   // Dark base (#18181B), Neon Lime 'h', Purple dot
  pink,   // Coral Pink base (#FF5A7E), Black 'h', White dot
}

/// HitungLogoWidget - Logo Minimalis Resmi Gen Z
///
/// Fitur:
/// - Squircle container continuous rounded corner (28% size).
/// - Huruf 'h' rounded tebal presisi (stroke rounded cap).
/// - Titik aksen '.' vibran di sudut kanan bawah.
/// - Wordmark 'hitung.' + tagline 'catat duit, tanpa ribet'.
/// - Pilihan 4 varian warna sesuai visual brand resmi.
/// - Micro-animation spring & scale saat dimuat.
class HitungLogoWidget extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isCompact;
  final bool showTagline;
  final HitungLogoVariant variant;
  final bool animate;
  final Color? textColor;

  const HitungLogoWidget({
    super.key,
    this.size = 48,
    this.showText = false,
    this.isCompact = false,
    this.showTagline = true,
    this.variant = HitungLogoVariant.lime,
    this.animate = true,
    this.textColor,
  });

  Color get _baseColor {
    switch (variant) {
      case HitungLogoVariant.lime:
        return AppColors.neonLime;
      case HitungLogoVariant.purple:
        return AppColors.brandPurple;
      case HitungLogoVariant.dark:
        return AppColors.brandDark;
      case HitungLogoVariant.pink:
        return AppColors.brandPink;
    }
  }

  Color get _hColor {
    switch (variant) {
      case HitungLogoVariant.lime:
        return AppColors.brandDark;
      case HitungLogoVariant.purple:
        return AppColors.neonLime;
      case HitungLogoVariant.dark:
        return AppColors.neonLime;
      case HitungLogoVariant.pink:
        return AppColors.brandDark;
    }
  }

  Color get _dotColor {
    switch (variant) {
      case HitungLogoVariant.lime:
        return AppColors.brandPurple;
      case HitungLogoVariant.purple:
        return Colors.white;
      case HitungLogoVariant.dark:
        return const Color(0xFFA78BFA);
      case HitungLogoVariant.pink:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _baseColor,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.25),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: CustomPaint(
        size: Size(size, size),
        painter: _MinimalistHPainter(
          hColor: _hColor,
          dotColor: _dotColor,
        ),
      ),
    );

    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (animate && !reduceMotion) {
      iconWidget = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.88, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: iconWidget,
      );
    }

    if (!showText) return iconWidget;

    final fontSize = isCompact ? size * 0.48 : size * 0.52;
    final finalTextColor = textColor ?? AppColors.textPrimary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        SizedBox(width: size * 0.26),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Wordmark: 'hitung.'
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'hitung',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: finalTextColor,
                    height: 1.0,
                  ),
                ),
                Container(
                  width: fontSize * 0.22,
                  height: fontSize * 0.22,
                  margin: EdgeInsets.only(left: size * 0.04),
                  decoration: BoxDecoration(
                    color: AppColors.brandPurple,
                    borderRadius: BorderRadius.circular(fontSize * 0.06),
                  ),
                ),
              ],
            ),
            if (!isCompact && showTagline) ...[
              SizedBox(height: size * 0.08),
              Text(
                'catat duit, tanpa ribet',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w500,
                  color: finalTextColor.withOpacity(0.7),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// CustomPainter untuk menggambar huruf 'h' minimalis dan titik '.' sesuai foto brand
class _MinimalistHPainter extends CustomPainter {
  final Color hColor;
  final Color dotColor;

  _MinimalistHPainter({
    required this.hColor,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Stroke width proporsional (~17% ukuran)
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

    // 1. Gambar tiang kiri huruf 'h'
    canvas.drawLine(
      Offset(stemX, stemTop),
      Offset(stemX, stemBottom),
      hPaint,
    );

    // 2. Gambar lengkungan bahu dan kaki kanan huruf 'h'
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

    // 3. Gambar titik bulat '.' berwarna ungu di kanan bawah
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final dotX = w * 0.81;
    final dotY = h * 0.71;
    final dotRadius = w * 0.082;

    canvas.drawCircle(Offset(dotX, dotY), dotRadius, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MinimalistHPainter oldDelegate) =>
      oldDelegate.hColor != hColor || oldDelegate.dotColor != dotColor;
}
