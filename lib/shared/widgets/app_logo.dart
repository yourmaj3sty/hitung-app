import 'package:flutter/material.dart';
import '../../core/widgets/hitung_logo_widget.dart';

export '../../core/widgets/hitung_logo_widget.dart';

/// Backward-compatible adapter that redirects to the new minimalist [HitungLogoWidget].
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool isCompact;
  final bool showTagline;
  final HitungLogoVariant variant;
  final bool animate;
  final Color? textColor;

  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = false,
    this.isCompact = false,
    this.showTagline = true,
    this.variant = HitungLogoVariant.lime,
    this.animate = true,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return HitungLogoWidget(
      size: size,
      showText: showText,
      isCompact: isCompact,
      showTagline: showTagline,
      variant: variant,
      animate: animate,
      textColor: textColor,
    );
  }
}
