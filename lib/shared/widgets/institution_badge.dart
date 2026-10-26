import 'package:flutter/material.dart';
import '../../core/constants/institution_presets.dart';
import '../../core/utils/color_utils.dart';

class InstitutionBadge extends StatelessWidget {
  final String institutionCode;
  final String? customLabel;
  final String? customColorHex;
  final bool isSavings;
  final double fontSize;

  const InstitutionBadge({
    super.key,
    required this.institutionCode,
    this.customLabel,
    this.customColorHex,
    this.isSavings = false,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    final preset = InstitutionPresets.getByCode(institutionCode);

    Color badgeColor;
    if (customColorHex != null && customColorHex!.isNotEmpty) {
      try {
        badgeColor = ColorUtils.fromHex(customColorHex!);
      } catch (_) {
        badgeColor = preset.color;
      }
    } else {
      badgeColor = preset.color;
    }

    final label = customLabel ?? preset.shortLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isSavings ? 'Tabungan: $label' : label,
            style: TextStyle(
              color: badgeColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
