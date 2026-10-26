import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/rupiah_input_formatter.dart';
import '../../../core/constants/institution_presets.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../core/widgets/hitung_logo_widget.dart';
import '../providers/onboarding_provider.dart';
import '../../../core/utils/color_utils.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController(text: 'GoPay');
  final _balanceController = TextEditingController(text: '0');
  String _selectedInstitutionCode = 'GOPAY';
  String _selectedIcon = 'smartphone';
  String _selectedColor = '#00AED6';
  String _walletType = 'E_WALLET';

  final List<String> _colors = [
    '#00AED6', // GoPay Cyan Blue
    '#00AA13', // Gojek Green
    '#3B82F6', // Blue
    '#FF8A00', // Orange
    '#8B5CF6', // Purple
    '#F04438', // Coral Red
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _selectPreset(InstitutionPreset preset) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedInstitutionCode = preset.code;
      _selectedColor = preset.colorHex;
      _nameController.text = preset.name;
      if (preset.category == InstitutionCategory.bank) {
        _walletType = 'BANK';
        _selectedIcon = 'landmark';
      } else if (preset.category == InstitutionCategory.eWallet) {
        _walletType = 'E_WALLET';
        _selectedIcon = 'smartphone';
      } else {
        _walletType = 'CASH';
        _selectedIcon = 'banknote';
      }
    });
  }

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    final name = _nameController.text.trim();
    final balance = CurrencyFormatter.parse(_balanceController.text);

    final success = await ref.read(onboardingControllerProvider.notifier).completeOnboarding(
      walletName: name.isEmpty ? 'Dompet Utama' : name,
      initialBalance: balance,
      iconName: _selectedIcon,
      colorHex: _selectedColor,
      walletType: _walletType,
      institutionCode: _selectedInstitutionCode,
    );

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terjadi kesalahan saat menyiapkan data awal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Rebranded Gen Z Logo Header with micro-animation
                const HitungLogoWidget(
                  size: 64,
                  showText: true,
                  animate: true,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Catat pengeluaran & kumpulkan tabungan dengan estetika modern, offline, dan tanpa ribet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 28),

                // Form Container (radius: 20, GoPay Clean)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 1),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Siapkan Dompet Pertamamu',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih preset Bank, Dompet Digital, atau Tunai favoritmu.',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Presets Grid Selector
                      SizedBox(
                        height: 38,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: InstitutionPresets.all.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final preset = InstitutionPresets.all[index];
                            final isSelected = _selectedInstitutionCode == preset.code;
                            return InkWell(
                              onTap: () => _selectPreset(preset),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? preset.color.withOpacity(0.15) : AppColors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? preset.color : AppColors.border,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: preset.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      preset.shortLabel,
                                      style: TextStyle(
                                        color: isSelected ? preset.color : AppColors.textPrimary,
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Wallet Name Field
                      const Text(
                        'Nama Dompet',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameController,
                        inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxNameLength)],
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'misal: GoPay, BCA, Tunai',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.gopayBlue, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Initial Balance Field
                      const Text(
                        'Saldo Awal (Opsional)',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _balanceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [RupiahInputFormatter()],
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                        decoration: InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: const TextStyle(
                            color: AppColors.gojekGreen,
                            fontWeight: FontWeight.w800,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                          hintText: '0',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceElevated,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.gojekGreen, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Icon & Color Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Ikon', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: IconHelper.availableWalletIcons.take(6).map((iconName) {
                                    final isSelected = _selectedIcon == iconName;
                                    return InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _selectedIcon = iconName);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected ? AppColors.gopayBlue : AppColors.border,
                                            width: isSelected ? 2 : 1,
                                          ),
                                        ),
                                        child: Icon(
                                          IconHelper.getIcon(iconName),
                                          size: 16,
                                          color: isSelected ? AppColors.gopayBlue : AppColors.textSecondary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Color
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _colors.map((hex) {
                                    final color = ColorUtils.fromHex(hex);
                                    final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
                                    return InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => _selectedColor = hex);
                                      },
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: color,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? AppColors.textPrimary : Colors.transparent,
                                            width: 2.5,
                                          ),
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button (radius: 14)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gojekGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Mulai Mencatat ✦',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
