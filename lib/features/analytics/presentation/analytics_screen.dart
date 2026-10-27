import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/formatted_amount_text.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/analytics_provider.dart';
import '../services/pdf_report_service.dart';
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/utils/color_utils.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateFilterProvider);
    final activeType = ref.watch(analyticsTypeProvider);
    final items = ref.watch(categoryAnalyticsListProvider);
    final comparisonAsync = ref.watch(monthComparisonProvider);
    final selectedIndex = ref.watch(selectedSliceIndexProvider);
    final trendPointsAsync = ref.watch(monthlyTrendProvider);
    final trendPeriod = ref.watch(trendPeriodMonthsProvider);

    final totalAmount = items.fold<int>(0, (sum, i) => sum + i.totalAmount);
    final isExpense = activeType == 'EXPENSE';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analisis Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.fileDown, size: 20),
            tooltip: 'Ekspor Laporan PDF',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final txs = ref.read(monthTransactionsAllWalletsProvider).value ?? [];
              final expenseCats = ref.read(expenseAnalyticsListProvider);
              final incomeCats = ref.read(incomeAnalyticsListProvider);
              final summary = ref.read(monthlySummaryAllWalletsProvider);
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(const SnackBar(content: Text('Menyiapkan laporan PDF...')));
              try {
                await PdfReportService().exportAndShareReport(
                  month: selectedDate,
                  transactions: txs,
                  expenseCategories: expenseCats,
                  incomeCategories: incomeCats,
                  totalIncome: summary.totalIncome,
                  totalExpense: summary.totalExpense,
                );
                messenger.hideCurrentSnackBar();
              } catch (_) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(const SnackBar(content: Text('Gagal membuat laporan PDF.')));
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Segmented Switch: Pengeluaran vs Pemasukan (Feature 8)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: EmilSpringButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(analyticsTypeProvider.notifier).state = 'EXPENSE';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isExpense ? AppColors.coralRed.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isExpense ? AppColors.coralRed : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pengeluaran',
                        style: TextStyle(
                          color: isExpense ? AppColors.coralRed : AppColors.textSecondary,
                          fontWeight: isExpense ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: EmilSpringButton(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(analyticsTypeProvider.notifier).state = 'INCOME';
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !isExpense ? AppColors.gojekGreen.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: !isExpense ? AppColors.gojekGreen : Colors.transparent,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pemasukan',
                        style: TextStyle(
                          color: !isExpense ? AppColors.gojekGreen : AppColors.textSecondary,
                          fontWeight: !isExpense ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Month Selector: < Oktober 2026 >
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 20, color: AppColors.textPrimary),
                  onPressed: () {
                    ref.read(selectedDateFilterProvider.notifier).state = DateTime(
                      selectedDate.year,
                      selectedDate.month - 1,
                      1,
                    );
                  },
                  visualDensity: VisualDensity.compact,
                ),
                Text(
                  DateFormatter.formatMonthYear(selectedDate),
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 20, color: AppColors.textPrimary),
                  onPressed: () {
                    ref.read(selectedDateFilterProvider.notifier).state = DateTime(
                      selectedDate.year,
                      selectedDate.month + 1,
                      1,
                    );
                  },
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Comparison Banner: Bulan Ini vs Bulan Lalu (FR-06 Acceptance Criteria)
          comparisonAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (comp) {
              final pct = comp.percentageChange;
              final isHigher = comp.diffAmount > 0;
              final isSame = comp.diffAmount == 0;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isHigher
                            ? AppColors.coralRed.withOpacity(0.15)
                            : isSame
                                ? AppColors.surfaceElevated
                                : AppColors.emeraldGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isHigher
                            ? LucideIcons.trendingUp
                            : isSame
                                ? LucideIcons.minus
                                : LucideIcons.trendingDown,
                        color: isHigher
                            ? AppColors.coralRed
                            : isSame
                                ? AppColors.textSecondary
                                : AppColors.emeraldGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Perbandingan vs Bulan Lalu',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                isHigher
                                    ? '+${CurrencyFormatter.format(comp.diffAmount)}'
                                    : isSame
                                        ? 'Sama dengan bulan lalu'
                                        : '-${CurrencyFormatter.format(comp.diffAmount.abs())}',
                                style: TextStyle(
                                  color: isHigher ? AppColors.coralRed : AppColors.emeraldGreen,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: CurrencyFormatter.tabularFigures,
                                ),
                              ),
                              if (pct != null && !isSame) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (isHigher ? AppColors.coralRed : AppColors.emeraldGreen).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${pct > 0 ? '+' : ''}$pct%',
                                    style: TextStyle(
                                      color: isHigher ? AppColors.coralRed : AppColors.emeraldGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Donut Chart Container
          if (items.isEmpty) ...[
            const EmptyStateWidget(
              icon: LucideIcons.pieChart,
              title: 'Belum Ada Pengeluaran',
              subtitle: 'Tidak ada transaksi pengeluaran pada bulan ini.',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Pie Chart
                  SizedBox(
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 65,
                            pieTouchData: PieTouchData(
                              touchCallback: (event, pieTouchResponse) {
                                if (!event.isInterestedForInteractions ||
                                    pieTouchResponse == null ||
                                    pieTouchResponse.touchedSection == null) {
                                  return;
                                }
                                final touchIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                ref.read(selectedSliceIndexProvider.notifier).state =
                                    touchIndex >= 0 && touchIndex < items.length ? touchIndex : null;
                              },
                            ),
                            sections: List.generate(items.length, (i) {
                              final it = items[i];
                              final isTouched = i == selectedIndex;
                              final color = ColorUtils.fromHex(it.category.colorHex);

                              return PieChartSectionData(
                                color: color,
                                value: it.totalAmount.toDouble(),
                                title: '', // We display details below or center
                                radius: isTouched ? 34.0 : 26.0,
                              );
                            }),
                          ),
                        ),
                        // Center Info
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedIndex != null && selectedIndex < items.length
                                  ? items[selectedIndex].category.name
                                  : (isExpense ? 'Total Belanja' : 'Total Pemasukan'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            FormattedAmountText(
                              amount: selectedIndex != null && selectedIndex < items.length
                                  ? items[selectedIndex].totalAmount
                                  : totalAmount,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (selectedIndex != null && selectedIndex < items.length) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${items[selectedIndex].percentage}%',
                                style: const TextStyle(color: AppColors.emeraldGreen, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ketuk irisan grafik untuk melihat rincian kategori',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Ranking Breakdown List
            const Text(
              'Rincian per Kategori',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),

            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final it = entry.value;
              final isHighlighted = index == selectedIndex;
              final color = ColorUtils.fromHex(it.category.colorHex);

              return InkWell(
                onTap: () {
                  ref.read(selectedSliceIndexProvider.notifier).state =
                      isHighlighted ? null : index;
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isHighlighted ? AppColors.surfaceElevated : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isHighlighted ? color : AppColors.border,
                      width: isHighlighted ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(IconHelper.getIcon(it.category.iconName), color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.category.name,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${it.transactionCount} transaksi • ${it.percentage}% dari total',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      FormattedAmountText(
                        amount: it.totalAmount,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],

          const SizedBox(height: 24),

          // Laporan Tren 6-12 Bulan (Feature 8)
          Container(
            padding: const EdgeInsets.all(18),
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
                      'Tren Riwayat Bulanan',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    // Periode Selector: 6 Bulan / 12 Bulan
                    Row(
                      children: [
                        _buildPeriodChip(ref, 6, trendPeriod),
                        const SizedBox(width: 6),
                        _buildPeriodChip(ref, 12, trendPeriod),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                trendPointsAsync.when(
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                  error: (err, _) => Text('Gagal memuat tren: $err', style: const TextStyle(color: AppColors.coralRed, fontSize: 12)),
                  data: (points) {
                    if (points.isEmpty) {
                      return const Text('Belum ada data tren yang cukup.', style: TextStyle(color: AppColors.textMuted));
                    }
                    return Column(
                      children: points.map((pt) {
                        final monthName = DateFormatter.formatMonthYear(pt.month);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    monthName,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Masuk:', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                          Text(
                                            CurrencyFormatter.formatRupiah(pt.totalIncome),
                                            style: const TextStyle(color: AppColors.gojekGreen, fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('Keluar:', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                          Text(
                                            CurrencyFormatter.formatRupiah(pt.totalExpense),
                                            style: const TextStyle(color: AppColors.coralRed, fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(WidgetRef ref, int months, int currentMonths) {
    final isSelected = months == currentMonths;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(trendPeriodMonthsProvider.notifier).state = months;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? AppColors.gopayBlue : AppColors.border),
        ),
        child: Text(
          '$months Bln',
          style: TextStyle(
            color: isSelected ? AppColors.gopayBlue : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
