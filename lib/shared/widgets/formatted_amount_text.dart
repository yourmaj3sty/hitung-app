import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// Komponen teks nominal uang dengan animasi berhitung (rolling/count up-down) saat nilai berubah.
/// Menghormati pengaturan sistem "reduce motion" dan batasan durasi 150-300 ms.
class FormattedAmountText extends StatelessWidget {
  final int amount;
  final TextStyle? style;
  final bool showSign;
  final bool includeSymbol;
  final bool autoColor; // green for +, red for -
  final bool animate;
  final Duration duration;

  const FormattedAmountText({
    super.key,
    required this.amount,
    this.style,
    this.showSign = false,
    this.includeSymbol = true,
    this.autoColor = false,
    this.animate = true,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (!animate || reduceMotion) {
      return _buildText(amount);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amount.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return _buildText(val.round());
      },
    );
  }

  Widget _buildText(int currentAmount) {
    Color? color = style?.color;
    if (autoColor) {
      if (currentAmount > 0) {
        color = AppColors.emeraldGreen;
      } else if (currentAmount < 0) {
        color = AppColors.coralRed;
      } else {
        color = AppColors.textSecondary;
      }
    }

    final effectiveStyle = (style ?? const TextStyle()).copyWith(
      color: color,
      fontFeatures: [
        ...?style?.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );

    return Text(
      CurrencyFormatter.format(
        currentAmount,
        includeSymbol: includeSymbol,
        showSign: showSign,
      ),
      style: effectiveStyle,
    );
  }
}
