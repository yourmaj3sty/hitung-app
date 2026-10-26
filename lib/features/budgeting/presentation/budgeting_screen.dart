import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/formatted_amount_text.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/budgeting_provider.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/rupiah_input_formatter.dart';

class BudgetingScreen extends ConsumerWidget {
  const BudgetingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateFilterProvider);
    final globalBudget = ref.watch(globalMonthlyBudgetProvider);
    final summary = ref.watch(monthlySummaryAllWalletsProvider); // Anggaran selalu dihitung dari semua dompet
    final categoryBudgets = ref.watch(categoryBudgetItemsProvider);

    // Global budget progress calculation
    final totalSpent = summary.totalExpense;
    int globalPercentage = 0;
    Color globalColor = AppColors.emeraldGreen;
    double globalProgress = 0.0;

    if (globalBudget != null && globalBudget > 0) {
      globalPercentage = (totalSpent * 100) ~/ globalBudget;
      globalProgress = (totalSpent / globalBudget).clamp(0.0, 1.0);
      if (globalPercentage < 80) {
        globalColor = AppColors.emeraldGreen;
      } else if (globalPercentage < 100) {
        globalColor = AppColors.warmOrange;
      } else {
        globalColor = AppColors.coralRed;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Anggaran Bulanan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Month Label
          Center(
            child: Text(
              'Periode: ${DateFormatter.formatMonthYear(selectedDate)}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),

          // Global Monthly Budget Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Batas Anggaran Global',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.edit3, size: 16, color: AppColors.emeraldGreen),
                      onPressed: () => _showEditBudgetDialog(
                        context,
                        title: 'Atur Anggaran Global',
                        initialValue: globalBudget,
                        onSaved: (val) {
                          ref.read(budgetControllerProvider.notifier).setGlobalMonthlyBudget(val);
                        },
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                if (globalBudget != null && globalBudget > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Terpakai', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          FormattedAmountText(
                            amount: totalSpent,
                            style: TextStyle(color: globalColor, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Batas Total', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 2),
                          FormattedAmountText(
                            amount: globalBudget,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: globalProgress,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation<Color>(globalColor),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$globalPercentage% terpakai',
                        style: TextStyle(color: globalColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        totalSpent > globalBudget
                            ? 'Melebihi anggaran!'
                            : 'Sisa ${CurrencyFormatter.format(globalBudget - totalSpent)}',
                        style: TextStyle(
                          color: totalSpent > globalBudget ? AppColors.coralRed : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const Text(
                    'Belum ada batas anggaran global. Ketuk ikon pensil di atas untuk mengatur.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Section Title: Category Budgets
          const Text(
            'Anggaran per Kategori',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),

          if (categoryBudgets.isEmpty) ...[
            const EmptyStateWidget(
              title: 'Belum Ada Kategori',
              subtitle: 'Kategori pengeluaran belum tersedia.',
            ),
          ] else ...[
            ...categoryBudgets.map((item) {
              final cat = item.category;
              final color = ColorUtils.fromHex(cat.colorHex);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(IconHelper.getIcon(cat.iconName), color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              if (item.hasBudget) ...[
                                Text(
                                  '${CurrencyFormatter.format(item.spentAmount)} dari ${CurrencyFormatter.format(item.budgetAmount!)}',
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ] else ...[
                                const Text('Belum diatur anggaran', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.edit2, size: 16, color: AppColors.textSecondary),
                          onPressed: () => _showEditBudgetDialog(
                            context,
                            title: 'Anggaran ${cat.name}',
                            initialValue: item.budgetAmount,
                            onSaved: (val) {
                              ref.read(budgetControllerProvider.notifier).updateCategoryBudget(cat.id, val);
                            },
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),

                    if (item.hasBudget) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.progressRatio,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceElevated,
                          valueColor: AlwaysStoppedAnimation<Color>(item.statusColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item.percentage}% terpakai',
                            style: TextStyle(
                              color: item.statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            item.remainingAmount < 0
                                ? 'Lebih ${CurrencyFormatter.format(item.remainingAmount.abs())}'
                                : 'Sisa ${CurrencyFormatter.format(item.remainingAmount)}',
                            style: TextStyle(
                              color: item.remainingAmount < 0 ? AppColors.coralRed : AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(
    BuildContext context, {
    required String title,
    required int? initialValue,
    required ValueChanged<int?> onSaved,
  }) {
    final controller = TextEditingController(
      text: initialValue != null ? CurrencyFormatter.format(initialValue, includeSymbol: false) : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontFeatures: CurrencyFormatter.tabularFigures),
          inputFormatters: const [RupiahInputFormatter()],
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(color: AppColors.emeraldGreen, fontWeight: FontWeight.w700),
            hintText: '0 (kosongkan untuk hapus)',
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          if (initialValue != null)
            TextButton(
              onPressed: () {
                onSaved(null);
                Navigator.of(ctx).pop();
              },
              child: const Text('Hapus Batas', style: TextStyle(color: AppColors.coralRed)),
            ),
          ElevatedButton(
            onPressed: () {
              final parsed = CurrencyFormatter.parse(controller.text);
              onSaved(parsed > 0 ? parsed : null);
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emeraldGreen, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
