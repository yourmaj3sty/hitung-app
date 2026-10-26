import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

// Selected Month and Year State
final selectedDateFilterProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

// Selected Wallet Filter (null = Semua Dompet)
final selectedWalletFilterProvider = StateProvider<String?>((ref) => null);

// Visibility of sensitive balance on home card
final isBalanceVisibleProvider = StateProvider<bool>((ref) => true);

/// ID transaksi yang baru di-swipe hapus. Disembunyikan secara sinkron agar
/// widget Dismissible langsung hilang dari tree, tanpa menunggu database selesai.
final pendingDeletedTxIdsProvider = StateProvider<Set<String>>((ref) => const <String>{});

/// Rentang bulan terpilih: [start, endExclusive).
({DateTime start, DateTime endExclusive}) monthRange(DateTime month) {
  return (
    start: DateTime(month.year, month.month, 1),
    endExclusive: DateTime(month.year, month.month + 1, 1),
  );
}

// Transactions stream for the selected month and wallet (dipakai Beranda)
final dashboardTransactionsProvider = StreamProvider<List<TransactionItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final range = monthRange(ref.watch(selectedDateFilterProvider));
  final walletId = ref.watch(selectedWalletFilterProvider);

  return db.watchTransactions(
    startDate: range.start,
    endDateExclusive: range.endExclusive,
    walletId: walletId,
  );
});

/// Transaksi bulan terpilih dari SEMUA dompet. Dipakai Anggaran & Analisis agar
/// angkanya tidak ikut berubah saat filter dompet di Beranda dipilih.
final monthTransactionsAllWalletsProvider = StreamProvider<List<TransactionItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final range = monthRange(ref.watch(selectedDateFilterProvider));
  return db.watchTransactions(startDate: range.start, endDateExclusive: range.endExclusive);
});

/// Transaksi Beranda tanpa yang sedang dihapus.
final visibleDashboardTransactionsProvider = Provider<List<TransactionItem>>((ref) {
  final txs = ref.watch(dashboardTransactionsProvider).value ?? const <TransactionItem>[];
  final hidden = ref.watch(pendingDeletedTxIdsProvider);
  if (hidden.isEmpty) return txs;
  return txs.where((t) => !hidden.contains(t.transaction.id)).toList();
});

// Daily grouped transactions structure
class DailyTransactions {
  final DateTime date;
  final List<TransactionItem> items;
  final int totalExpense;
  final int totalIncome;

  DailyTransactions({
    required this.date,
    required this.items,
    required this.totalExpense,
    required this.totalIncome,
  });

  int get netTotal => totalIncome - totalExpense;
}

// Grouped transactions provider
final groupedDashboardTransactionsProvider = Provider<List<DailyTransactions>>((ref) {
  final txs = ref.watch(visibleDashboardTransactionsProvider);

  final Map<String, List<TransactionItem>> map = {};
  for (final item in txs) {
    final d = item.transaction.transactionDate;
    final key = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    map.putIfAbsent(key, () => []).add(item);
  }

  final result = <DailyTransactions>[];
  map.forEach((key, items) {
    int expense = 0;
    int income = 0;
    for (final it in items) {
      if (it.transaction.type == 'EXPENSE') {
        expense += it.transaction.amount;
      } else if (it.transaction.type == 'INCOME') {
        income += it.transaction.amount;
      }
    }
    final d = items.first.transaction.transactionDate;
    result.add(DailyTransactions(
      date: DateTime(d.year, d.month, d.day),
      items: items,
      totalExpense: expense,
      totalIncome: income,
    ));
  });

  result.sort((a, b) => b.date.compareTo(a.date));
  return result;
});

// Monthly summary provider (Total Income, Total Expense, Net)
class MonthlySummary {
  final int totalIncome;
  final int totalExpense;
  final int netSavings;

  MonthlySummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
  });

  factory MonthlySummary.fromItems(Iterable<TransactionItem> items) {
    int income = 0;
    int expense = 0;
    for (final item in items) {
      // PRD FR-03: Transfer TIDAK dihitung sebagai pengeluaran/pemasukan bulanan
      if (item.transaction.type == 'INCOME') {
        income += item.transaction.amount;
      } else if (item.transaction.type == 'EXPENSE') {
        expense += item.transaction.amount;
      }
    }
    return MonthlySummary(totalIncome: income, totalExpense: expense, netSavings: income - expense);
  }
}

/// Ringkasan Beranda (mengikuti filter dompet).
final monthlySummaryProvider = Provider<MonthlySummary>((ref) {
  return MonthlySummary.fromItems(ref.watch(visibleDashboardTransactionsProvider));
});

/// Ringkasan seluruh dompet (dipakai Anggaran Global).
final monthlySummaryAllWalletsProvider = Provider<MonthlySummary>((ref) {
  final txs = ref.watch(monthTransactionsAllWalletsProvider).value ?? const <TransactionItem>[];
  return MonthlySummary.fromItems(txs);
});
