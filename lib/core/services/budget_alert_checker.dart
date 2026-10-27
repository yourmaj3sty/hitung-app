import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import 'notification_service.dart';

/// Mengirim notifikasi anggaran saat pengeluaran bulan berjalan melewati 80% atau 100%.
/// Setiap ambang hanya diberitahukan SEKALI per anggaran per bulan, agar notifikasi
/// tidak muncul di setiap transaksi berikutnya.
class BudgetAlertChecker {
  final AppDatabase db;
  final SharedPreferences prefs;
  final Future<void> Function({
    required String categoryOrGlobal,
    required int percentage,
    required int current,
    required int limit,
  }) notify;

  BudgetAlertChecker(this.db, this.prefs, {Future<void> Function({
    required String categoryOrGlobal,
    required int percentage,
    required int current,
    required int limit,
  })? notify})
      : notify = notify ?? NotificationService().showBudgetAlert;

  static String _monthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Kunci preferensi berisi ambang tertinggi yang sudah diberitahukan (80/100).
  static String sentKey(String scope, DateTime month) => 'budget_alert_sent_${scope}_${_monthKey(month)}';

  static int? thresholdFor(int percentage) => percentage >= 100 ? 100 : (percentage >= 80 ? 80 : null);

  Future<void> check({String? categoryId, required DateTime transactionDate, DateTime? now}) async {
    try {
      if (!(prefs.getBool(AppConstants.prefBudgetAlertEnabled) ?? true)) return;
      final today = now ?? DateTime.now();
      // Transaksi bulan lalu/depan tidak memicu peringatan anggaran bulan berjalan.
      if (_monthKey(transactionDate) != _monthKey(today)) return;

      if (categoryId != null) {
        final cat = await db.getCategoryById(categoryId);
        final budget = cat?.monthlyBudget;
        if (cat != null && budget != null && budget > 0) {
          final spent = await db.getMonthlyExpenseForCategory(cat.id, today);
          await _maybeNotify('cat_${cat.id}', cat.name, spent, budget, today);
        }
      }

      final globalBudget = prefs.getInt(AppConstants.prefGlobalMonthlyBudget);
      if (globalBudget != null && globalBudget > 0) {
        final spent = await db.getMonthlyTotalExpense(today);
        await _maybeNotify('global', 'Keseluruhan', spent, globalBudget, today);
      }
    } catch (_) {
      // Notifikasi bersifat tambahan; kegagalan tidak boleh mengganggu pencatatan.
    }
  }

  Future<void> _maybeNotify(String scope, String label, int spent, int budget, DateTime month) async {
    final pct = (spent * 100) ~/ budget;
    final threshold = thresholdFor(pct);
    if (threshold == null) return;
    final key = sentKey(scope, month);
    final alreadySent = prefs.getInt(key) ?? 0;
    if (threshold <= alreadySent) return;
    await notify(categoryOrGlobal: label, percentage: pct, current: spent, limit: budget);
    await prefs.setInt(key, threshold);
  }
}
