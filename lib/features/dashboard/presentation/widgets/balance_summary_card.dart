import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/institution_presets.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../shared/widgets/formatted_amount_text.dart';
import '../../../../shared/widgets/institution_badge.dart';
import '../../../../core/animations/emil_spring_button.dart';
import '../../providers/dashboard_provider.dart';
import '../../../wallets/providers/wallet_provider.dart';

class BalanceSummaryCard extends ConsumerWidget {
  final List<Wallet> wallets;
  final MonthlySummary monthlySummary;
  final String? selectedWalletId;
  final ValueChanged<String?> onSelectWallet;
  final VoidCallback onAddWallet;

  const BalanceSummaryCard({
    super.key,
    required this.wallets,
    required this.monthlySummary,
    required this.selectedWalletId,
    required this.onSelectWallet,
    required this.onAddWallet,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVisible = ref.watch(isBalanceVisibleProvider);
    final activeFilter = ref.watch(heroWalletFilterProvider);

    // Filter wallets according to top pill switch
    final dailyWallets = wallets.where((w) => w.walletType != 'SAVINGS').toList();
    final savingsWallets = wallets.where((w) => w.walletType == 'SAVINGS').toList();

    int displayedBalance;
    List<Wallet> carouselWallets;

    switch (activeFilter) {
      case HeroWalletFilter.daily:
        displayedBalance = dailyWallets.fold(0, (sum, w) => sum + w.currentBalance);
        carouselWallets = dailyWallets;
        break;
      case HeroWalletFilter.savings:
        displayedBalance = savingsWallets.fold(0, (sum, w) => sum + w.currentBalance);
        carouselWallets = savingsWallets;
        break;
      case HeroWalletFilter.all:
        displayedBalance = wallets.fold(0, (sum, w) => sum + w.currentBalance);
        carouselWallets = wallets;
        break;
    }

    // If a specific wallet is selected in the carousel, show that wallet's balance
    if (selectedWalletId != null) {
      final selected = wallets.where((w) => w.id == selectedWalletId).firstOrNull;
      if (selected != null) {
        displayedBalance = selected.currentBalance;
      }
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00AED6), Color(0xFF0082A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.heroShadow,
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Segmented Pill Switcher di bagian atas kartu: Semua Saldo | Dompet Harian | Tabungan
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _buildSegmentPill(
                  label: 'Semua Saldo',
                  isSelected: activeFilter == HeroWalletFilter.all,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(heroWalletFilterProvider.notifier).state = HeroWalletFilter.all;
                    onSelectWallet(null);
                  },
                ),
                _buildSegmentPill(
                  label: 'Dompet Harian',
                  isSelected: activeFilter == HeroWalletFilter.daily,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(heroWalletFilterProvider.notifier).state = HeroWalletFilter.daily;
                    onSelectWallet(null);
                  },
                ),
                _buildSegmentPill(
                  label: 'Tabungan (✦)',
                  isSelected: activeFilter == HeroWalletFilter.savings,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(heroWalletFilterProvider.notifier).state = HeroWalletFilter.savings;
                    onSelectWallet(null);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Nominal Saldo Utama: 32px ExtraBold + Tabular Figures + Eye toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          activeFilter == HeroWalletFilter.savings
                              ? 'Total Dana Tabungan'
                              : activeFilter == HeroWalletFilter.daily
                                  ? 'Saldo Dompet Harian'
                                  : 'Total Seluruh Saldo',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        EmilSpringButton(
                          onTap: () {
                            ref.read(isBalanceVisibleProvider.notifier).state = !isVisible;
                          },
                          pressScale: 0.85,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isVisible ? LucideIcons.eye : LucideIcons.eyeOff,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isVisible)
                      FormattedAmountText(
                        amount: displayedBalance,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.6,
                          height: 1.15,
                        ),
                      )
                    else
                      const Text(
                        'Rp ••••••••',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
              // Cashflow mini summary pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.arrowDownLeft, color: Color(0xFF86EFAC), size: 12),
                        const SizedBox(width: 4),
                        FormattedAmountText(
                          amount: monthlySummary.totalIncome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.arrowUpRight, color: Color(0xFFFCA5A5), size: 12),
                        const SizedBox(width: 4),
                        FormattedAmountText(
                          amount: monthlySummary.totalExpense,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFeatures: CurrencyFormatter.tabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Horizontal Mini-Cards Carousel (radius: 16) di dalam kartu Hero
          SizedBox(
            height: 84,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: carouselWallets.length + 1,
              itemBuilder: (context, index) {
                // Last item is '+ Tambah' button card
                if (index == carouselWallets.length) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onAddWallet();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 90,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.plus, color: Colors.white, size: 22),
                            SizedBox(height: 4),
                            Text(
                              '+ Tambah',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final wallet = carouselWallets[index];
                final isSelected = selectedWalletId == wallet.id;
                final isSavings = wallet.walletType == 'SAVINGS';
                final preset = InstitutionPresets.getByCode(wallet.institutionCode);

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onSelectWallet(isSelected ? null : wallet.id);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? AppColors.electricEmerald : Colors.transparent,
                          width: isSelected ? 2.0 : 0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: preset.color.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  IconHelper.getIcon(wallet.iconName),
                                  size: 13,
                                  color: preset.color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  wallet.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              InstitutionBadge(
                                institutionCode: wallet.institutionCode,
                                isSavings: isSavings,
                                fontSize: 9,
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVisible
                                    ? CurrencyFormatter.formatRupiah(wallet.currentBalance)
                                    : 'Rp ••••••',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: CurrencyFormatter.tabularFigures,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isSavings && wallet.targetAmount != null && wallet.targetAmount! > 0) ...[
                                const SizedBox(height: 3),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (wallet.currentBalance / wallet.targetAmount!).clamp(0.0, 1.0),
                                    minHeight: 4,
                                    backgroundColor: AppColors.border,
                                    valueColor: AlwaysStoppedAnimation<Color>(preset.color),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: EmilSpringButton(
        onTap: onTap,
        pressScale: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.gopayBlueDark : Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
