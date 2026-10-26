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

/// Rincian pengeluaran per kategori bulan terpilih (semua dompet).
/// Kategori yang sudah dihapus tetap dihitung agar total dan persentase tetap benar.
final categoryAnalyticsListProvider = Provider<List<CategoryAnalyticsItem>>((ref) {
  final txs = ref.watch(monthTransactionsAllWalletsProvider).value ?? const <TransactionItem>[];

  final Map<String, Category> categoriesById = {};
  final Map<String, int> amounts = {};
  final Map<String, int> counts = {};

  for (final item in txs) {
    if (item.transaction.type != 'EXPENSE') continue;
    final cat = item.category ?? uncategorizedExpenseCategory;
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
/// Berbasis stream, jadi langsung ter-update saat transaksi ditambah/dihapus.
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

// Selected slice index in donut chart
final selectedSliceIndexProvider = StateProvider<int?>((ref) => null);
