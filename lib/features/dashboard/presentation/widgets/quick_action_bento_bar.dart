import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/animations/emil_spring_button.dart';
import '../../../../core/constants/app_colors.dart';

class QuickActionBentoBar extends StatelessWidget {
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onTransfer;
  final VoidCallback onSavings;

  const QuickActionBentoBar({
    super.key,
    required this.onExpense,
    required this.onIncome,
    required this.onTransfer,
    required this.onSavings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _buildBentoItem(
          icon: LucideIcons.minus,
          label: 'Catat Keluar',
          sublabel: '(-)',
          accentColor: AppColors.coralRed,
          bgColor: AppColors.gopayRedLight,
          onTap: onExpense,
        ),
        const SizedBox(width: 8),
        _buildBentoItem(
          icon: LucideIcons.plus,
          label: 'Catat Masuk',
          sublabel: '(+)',
          accentColor: AppColors.gojekGreen,
          bgColor: AppColors.gojekGreenLight,
          onTap: onIncome,
        ),
        const SizedBox(width: 8),
        _buildBentoItem(
          icon: LucideIcons.arrowRightLeft,
          label: 'Pindah Dana',
          sublabel: 'Transfer',
          accentColor: AppColors.gopayBlue,
          bgColor: AppColors.gopayBlueLight,
          onTap: onTransfer,
        ),
        const SizedBox(width: 8),
        _buildBentoItem(
          icon: LucideIcons.sparkles,
          label: 'Isi Tabungan',
          sublabel: '(✦)',
          accentColor: const Color(0xFF00A2E9),
          bgColor: const Color(0xFFE0F7FE),
          onTap: onSavings,
        ),
      ],
    );
  }

  Widget _buildBentoItem({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color accentColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: EmilSpringButton(
        onTap: onTap,
        pressScale: 0.93,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(icon, color: accentColor, size: 18),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
