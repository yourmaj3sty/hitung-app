import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_colors.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? lottieAsset;
  final bool useLottie;

  const EmptyStateWidget({
    super.key,
    this.icon = LucideIcons.inbox,
    required this.title,
    this.subtitle,
    this.action,
    this.lottieAsset = 'assets/lottie/empty_transactions.json',
    this.useLottie = true,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (useLottie && !reduceMotion) ...[
              SizedBox(
                width: 130,
                height: 130,
                child: Lottie.asset(
                  lottieAsset ?? 'assets/lottie/empty_transactions.json',
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(),
                ),
              ),
            ] else ...[
              _buildFallbackIcon(),
            ],
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Icon(
        icon,
        size: 38,
        color: AppColors.textMuted,
      ),
    );
  }
}
