import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../shared/widgets/formatted_amount_text.dart';
import '../../../../shared/widgets/institution_badge.dart';
import '../../providers/dashboard_provider.dart';
import '../../../../core/utils/color_utils.dart';

class DailyTransactionGroupWidget extends StatelessWidget {
  final DailyTransactions dailyGroup;
  final ValueChanged<TransactionItem> onDelete;

  const DailyTransactionGroupWidget({
    super.key,
    required this.dailyGroup,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Daily Header: Tanggal & Subtotal harian
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormatter.formatDailyHeader(dailyGroup.date),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              FormattedAmountText(
                amount: dailyGroup.netTotal,
                showSign: true,
                autoColor: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  fontFeatures: CurrencyFormatter.tabularFigures,
                ),
              ),
            ],
          ),
        ),

        // Grouped Daily Card: radius: 20
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: AppColors.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: dailyGroup.items.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
              itemBuilder: (context, index) {
                final item = dailyGroup.items[index];
                final tx = item.transaction;

                return Dismissible(
                  key: Key(tx.id),
                  direction: DismissDirection.endToStart,
                  movementDuration: const Duration(milliseconds: 200),
                  resizeDuration: const Duration(milliseconds: 250),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.coralRed,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Hapus',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  onDismissed: (_) => onDelete(item),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(tx.id),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) {
                      final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                      if (reduceMotion) return child!;
                      return Opacity(
                        opacity: val,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1.0 - val)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildTransactionTile(item),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildTransactionTile(TransactionItem item) {
    final tx = item.transaction;
    final isExpense = tx.type == 'EXPENSE';
    final isIncome = tx.type == 'INCOME';
    final isTransfer = tx.type == 'TRANSFER';

    IconData iconData = LucideIcons.circleDollarSign;
    Color iconColor = AppColors.textSecondary;

    if (isTransfer) {
      final isToSavings = item.toWallet?.walletType == 'SAVINGS';
      iconData = isToSavings ? LucideIcons.sparkles : LucideIcons.arrowRightLeft;
      iconColor = isToSavings ? AppColors.gopayBlue : AppColors.infoBlue;
    } else if (item.category != null) {
      iconData = IconHelper.getIcon(item.category!.iconName);
      iconColor = ColorUtils.fromHex(item.category!.colorHex);
    }

    String title;
    if (isTransfer) {
      if (item.toWallet?.walletType == 'SAVINGS') {
        title = 'Isi Tabungan: ${item.toWallet?.name ?? 'Tabungan'}';
      } else {
        title = 'Transfer: ${item.wallet.name} → ${item.toWallet?.name ?? 'Dompet'}';
      }
    } else {
      title = item.category?.name ?? 'Tanpa Kategori';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Category Icon Container (radius: 14)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Details Column with Title & Bank/E-Wallet Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Small Bank / E-Wallet Pill Badge
                    if (!isTransfer)
                      InstitutionBadge(
                        institutionCode: item.wallet.institutionCode,
                        customLabel: item.wallet.name,
                        customColorHex: item.wallet.colorHex,
                        isSavings: item.wallet.walletType == 'SAVINGS',
                      )
                    else if (item.toWallet != null)
                      InstitutionBadge(
                        institutionCode: item.toWallet!.institutionCode,
                        customLabel: item.toWallet!.name,
                        customColorHex: item.toWallet!.colorHex,
                        isSavings: item.toWallet!.walletType == 'SAVINGS',
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.wallet.name,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (tx.note != null && tx.note!.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      Expanded(
                        child: Text(
                          tx.note!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Amount
          FormattedAmountText(
            amount: isExpense ? -tx.amount : tx.amount,
            showSign: isExpense || isIncome,
            autoColor: !isTransfer,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isTransfer ? AppColors.infoBlue : null,
              fontFeatures: CurrencyFormatter.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}
