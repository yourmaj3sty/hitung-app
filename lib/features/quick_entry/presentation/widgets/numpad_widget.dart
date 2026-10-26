import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class NumpadWidget extends StatelessWidget {
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onBackspacePressed;
  final VoidCallback onClearPressed;

  const NumpadWidget({
    super.key,
    required this.onKeyPressed,
    required this.onBackspacePressed,
    required this.onClearPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Tombol '000' untuk ribuan cepat (Gen Z tactile style)
            _buildKey('000', isAccent: true),
            _buildKey('0'),
            _buildBackspaceKey(),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, {bool isAccent = false}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: isAccent ? AppColors.gopayBlueLight : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onKeyPressed(label);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isAccent ? AppColors.gopayBlue.withOpacity(0.3) : AppColors.border,
                  width: 1,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isAccent ? AppColors.gopayBlueDark : AppColors.textPrimary,
                  fontSize: label.length > 1 ? 18 : 22,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onBackspacePressed();
            },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onClearPressed();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: const Icon(
                Icons.backspace_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
