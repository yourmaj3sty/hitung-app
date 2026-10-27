import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class CategoryAnalyticsItem {
  final Category category;
  final int totalAmount;
  final int transactionCount;
  final int percentage; // 0..100

  CategoryAnalyticsItem({
    required this.category,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

/// Kategori pengganti untuk pengeluaran tanpa kategori.
const uncategorizedExpenseCategory = Category(
  id: '__uncategorized__',
  name: 'Tanpa Kategori',
  type: 'EXPENSE',
  iconName: 'more-horizontal',
  colorHex: '#94A3B8',
  isDeleted: false,
);

/// Kategori pengganti untuk pemasukan tanpa kategori.
const uncategorizedIncomeCategory = Category(
  id: '__uncategorized_income__',
  name: 'Tanpa Kategori',
  type: 'INCOME',
  iconName: 'wallet',
  colorHex: '#10B981',
  isDeleted: false,
);

/// Tipe analitik aktif: 'EXPENSE' (Pengeluaran) atau 'INCOME' (Pemasukan) (Feature 8)
final analyticsTypeProvider = StateProvider<String>((ref) => 'EXPENSE');

/// Periode tren: 6 bulan atau 12 bulan
final trendPeriodMonthsProvider = StateProvider<int>((ref) => 6);

/// Membagi 100% ke tiap nilai dengan metode sisa terbesar (largest remainder),
/// sehingga persentase bulat selalu berjumlah tepat 100.
List<int> distributePercentages(List<int> amounts) {
  final total = amounts.fold<int>(0, (s, a) => s + a);
  if (total <= 0) return List.filled(amounts.length, 0);

  final floors = <int>[];
  final remainders = <int>[];
  for (final a in amounts) {
    floors.add((a * 100) ~/ total);
    remainders.add((a * 100) % total);
  }
  var leftover = 100 - floors.fold<int>(0, (s, f) => s + f);
  final order = List<int>.generate(amounts.length, (i) => i)
    ..sort((a, b) => remainders[b].compareTo(remainders[a]));
  for (final i in order) {
    if (leftover <= 0) break;
    floors[i]++;
    leftover--;
  }
  return floors;
}

List<CategoryAnalyticsItem> _calculateCategoryAnalytics(List<TransactionItem> txs, String targetType) {
  final Map<String, Category> categoriesById = {};
  final Map<String, int> amounts = {};
  final Map<String, int> counts = {};

  final defaultCat = targetType == 'EXPENSE'
      ? uncategorizedExpenseCategory
      : uncategorizedIncomeCategory;

  for (final item in txs) {
    if (item.transaction.type != targetType) continue;
    final cat = item.category ?? defaultCat;
    categoriesById[cat.id] = cat;
    amounts[cat.id] = (amounts[cat.id] ?? 0) + item.transaction.amount;
    counts[cat.id] = (counts[cat.id] ?? 0) + 1;
  }

  final ids = amounts.keys.toList()..sort((a, b) => amounts[b]!.compareTo(amounts[a]!));
  final percentages = distributePercentages([for (final id in ids) amounts[id]!]);

  return [
    for (var i = 0; i < ids.length; i++)
      CategoryAnalyticsItem(
        category: categoriesById[ids[i]]!,
        totalAmount: amounts[ids[i]]!,
        transactionCount: counts[ids[i]]!,
        percentage: percentages[i],
      ),
  ];
}

/// Rincian pengeluaran per kategori bulan terpilih (semua dompet).
final expenseAnalyticsListProvider = Provider<List<CategoryAnalyticsItem>>((ref) {
  final txs = ref.watch(monthTransactionsAllWalletsProvider).value ?? const <TransactionItem>[];
  return _calculateCategoryAnalytics(txs, 'EXPENSE');
});

/// Rincian pemasukan per kategori bulan terpilih (semua dompet).
final incomeAnalyticsListProvider = Provider<List<CategoryAnalyticsItem>>((ref) {
  final txs = ref.watch(monthTransactionsAllWalletsProvider).value ?? const <TransactionItem>[];
  return _calculateCategoryAnalytics(txs, 'INCOME');
});

/// Rincian kategori aktif berdasarkan tipe tab yang dipilih ('EXPENSE' atau 'INCOME').
final categoryAnalyticsListProvider = Provider<List<CategoryAnalyticsItem>>((ref) {
  final type = ref.watch(analyticsTypeProvider);
  return type == 'EXPENSE'
      ? ref.watch(expenseAnalyticsListProvider)
      : ref.watch(incomeAnalyticsListProvider);
});

// Month-over-month comparison provider
class MonthComparison {
  final int currentMonthExpense;
  final int previousMonthExpense;

  MonthComparison({
    required this.currentMonthExpense,
    required this.previousMonthExpense,
  });

  int get diffAmount => currentMonthExpense - previousMonthExpense;

  int? get percentageChange {
    if (previousMonthExpense == 0) return null;
    return (diffAmount * 100) ~/ previousMonthExpense;
  }
}

/// Perbandingan pengeluaran bulan ini vs bulan lalu (semua dompet).
final monthComparisonProvider = StreamProvider<MonthComparison>((ref) {
  final db = ref.watch(databaseProvider);
  final selected = ref.watch(selectedDateFilterProvider);

  final current = monthRange(selected);
  final previousStart = DateTime(selected.year, selected.month - 1, 1);

  return db.watchExpensesBetween(previousStart, current.endExclusive).map((txs) {
    var cur = 0;
    var prev = 0;
    for (final t in txs) {
      if (t.transactionDate.isBefore(current.start)) {
        prev += t.amount;
      } else {
        cur += t.amount;
      }
    }
    return MonthComparison(currentMonthExpense: cur, previousMonthExpense: prev);
  });
});

// Data tren bulanan (Feature 8)
class MonthlyTrendPoint {
  final DateTime month;
  final int totalIncome;
  final int totalExpense;

  MonthlyTrendPoint({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
  });

  int get netSavings => totalIncome - totalExpense;
}

final monthlyTrendProvider = StreamProvider<List<MonthlyTrendPoint>>((ref) {
  final db = ref.watch(databaseProvider);
  final monthsCount = ref.watch(trendPeriodMonthsProvider);
  final now = DateTime.now();

  // Hitung rentang dari N bulan lalu sampai akhir bulan ini
  final start = DateTime(now.year, now.month - (monthsCount - 1), 1);
  final endExclusive = DateTime(now.year, now.month + 1, 1);

  return db.watchTransactions(startDate: start, endDateExclusive: endExclusive).map((txs) {
    final Map<String, ({int income, int expense})> monthTotals = {};

    // Inisialisasi setiap bulan dalam urutan kronologis
    final points = <MonthlyTrendPoint>[];
    for (var i = monthsCount - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      monthTotals[key] = (income: 0, expense: 0);
    }

    for (final item in txs) {
      final tx = item.transaction;
      final key = '${tx.transactionDate.year}-${tx.transactionDate.month.toString().padLeft(2, '0')}';
      if (monthTotals.containsKey(key)) {
        final current = monthTotals[key]!;
        if (tx.type == 'INCOME') {
          monthTotals[key] = (income: current.income + tx.amount, expense: current.expense);
        } else if (tx.type == 'EXPENSE') {
          monthTotals[key] = (income: current.income, expense: current.expense + tx.amount);
        }
      }
    }

    for (var i = monthsCount - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      final total = monthTotals[key] ?? (income: 0, expense: 0);
      points.add(MonthlyTrendPoint(
        month: m,
        totalIncome: total.income,
        totalExpense: total.expense,
      ));
    }

    return points;
  });
});

// Selected slice index in donut chart
final selectedSliceIndexProvider = StateProvider<int?>((ref) => null);
