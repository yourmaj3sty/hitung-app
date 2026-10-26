class SeedCategoryItem {
  final String id;
  final String name;
  final String type; // 'EXPENSE' or 'INCOME'
  final String iconName;
  final String colorHex;
  final int? monthlyBudget;

  const SeedCategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.colorHex,
    this.monthlyBudget,
  });
}

class SeedData {
  // 10 Kategori Bawaan (7 Expense, 3 Income) sesuai FR-01 Acceptance Criteria
  static const List<SeedCategoryItem> defaultCategories = [
    // --- 7 EXPENSES ---
    SeedCategoryItem(
      id: 'cat_expense_food',
      name: 'Makanan & Minuman',
      type: 'EXPENSE',
      iconName: 'utensils',
      colorHex: '#EF4444', // Coral / Red
      monthlyBudget: 2000000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_transport',
      name: 'Transportasi',
      type: 'EXPENSE',
      iconName: 'car',
      colorHex: '#3B82F6', // Blue
      monthlyBudget: 800000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_shopping',
      name: 'Belanja',
      type: 'EXPENSE',
      iconName: 'shopping-bag',
      colorHex: '#8B5CF6', // Purple
      monthlyBudget: 1000000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_bills',
      name: 'Tagihan & Utilitas',
      type: 'EXPENSE',
      iconName: 'receipt',
      colorHex: '#F59E0B', // Amber
      monthlyBudget: 1500000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_entertainment',
      name: 'Hiburan & Hobi',
      type: 'EXPENSE',
      iconName: 'gamepad-2',
      colorHex: '#EC4899', // Pink
      monthlyBudget: 500000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_health',
      name: 'Kesehatan',
      type: 'EXPENSE',
      iconName: 'heart-pulse',
      colorHex: '#10B981', // Emerald Green
      monthlyBudget: 500000,
    ),
    SeedCategoryItem(
      id: 'cat_expense_other',
      name: 'Lain-lain',
      type: 'EXPENSE',
      iconName: 'more-horizontal',
      colorHex: '#64748B', // Slate
      monthlyBudget: null,
    ),

    // --- 3 INCOMES ---
    SeedCategoryItem(
      id: 'cat_income_salary',
      name: 'Gaji Utama',
      type: 'INCOME',
      iconName: 'banknote',
      colorHex: '#10B981', // Emerald
      monthlyBudget: null,
    ),
    SeedCategoryItem(
      id: 'cat_income_bonus',
      name: 'Bonus & THR',
      type: 'INCOME',
      iconName: 'gift',
      colorHex: '#06B6D4', // Cyan
      monthlyBudget: null,
    ),
    SeedCategoryItem(
      id: 'cat_income_investment',
      name: 'Investasi & Passive',
      type: 'INCOME',
      iconName: 'trending-up',
      colorHex: '#6366F1', // Indigo
      monthlyBudget: null,
    ),
  ];
}
