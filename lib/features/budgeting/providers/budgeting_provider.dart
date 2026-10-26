import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';

class CategoryBudgetItem {
  final Category category;
  final int spentAmount;
  final int? budgetAmount;

  CategoryBudgetItem({
    required this.category,
    required this.spentAmount,
    this.budgetAmount,
  });

  bool get hasBudget => budgetAmount != null && budgetAmount! > 0;

  // Percentage calculated with integer division
  int get percentage {
    if (!hasBudget) return 0;
    return (spentAmount * 100) ~/ budgetAmount!;
  }

  int get remainingAmount {
    if (!hasBudget) return 0;
    return budgetAmount! - spentAmount;
  }

  // FR-05 Acceptance Criteria:
  // Hijau (<80%), Oranye #F97316 (80%-99%), Merah #F43F5E (>=100%)
  Color get statusColor {
    if (!hasBudget) return AppColors.emeraldGreen;
    if (percentage < 80) {
      return AppColors.emeraldGreen;
    } else if (percentage < 100) {
      return AppColors.warmOrange;
    } else {
      return AppColors.coralRed;
    }
  }

  double get progressRatio {
    if (!hasBudget) return 0.0;
    final r = spentAmount / budgetAmount!;
    return r > 1.0 ? 1.0 : r;
  }
}

final globalMonthlyBudgetProvider = StateProvider<int?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final val = prefs.getInt(AppConstants.prefGlobalMonthlyBudget);
  return val;
});

final categoryBudgetItemsProvider = Provider<List<CategoryBudgetItem>>((ref) {
  final categoriesAsync = ref.watch(activeCategoriesStreamProvider('EXPENSE'));
  final txsAsync = ref.watch(monthTransactionsAllWalletsProvider);

  final categories = categoriesAsync.value ?? [];
  final txs = txsAsync.value ?? [];

  // Group expenses by categoryId
  final Map<String, int> expenseMap = {};
  for (final item in txs) {
    if (item.transaction.type == 'EXPENSE' && item.transaction.categoryId != null) {
      final catId = item.transaction.categoryId!;
      expenseMap[catId] = (expenseMap[catId] ?? 0) + item.transaction.amount;
    }
  }

  return categories.map((cat) {
    return CategoryBudgetItem(
      category: cat,
      spentAmount: expenseMap[cat.id] ?? 0,
      budgetAmount: cat.monthlyBudget,
    );
  }).toList();
});

class BudgetController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  BudgetController(this._ref) : super(const AsyncValue.data(null));

  Future<void> updateCategoryBudget(String categoryId, int? budget) async {
    final db = _ref.read(databaseProvider);
    await db.updateCategoryBudget(categoryId, budget);
  }

  Future<void> setGlobalMonthlyBudget(int? budget) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    if (budget == null || budget <= 0) {
      await prefs.remove(AppConstants.prefGlobalMonthlyBudget);
      _ref.read(globalMonthlyBudgetProvider.notifier).state = null;
    } else {
      await prefs.setInt(AppConstants.prefGlobalMonthlyBudget, budget);
      _ref.read(globalMonthlyBudgetProvider.notifier).state = budget;
    }
  }
}

final budgetControllerProvider = StateNotifierProvider<BudgetController, AsyncValue<void>>((ref) {
  return BudgetController(ref);
});
