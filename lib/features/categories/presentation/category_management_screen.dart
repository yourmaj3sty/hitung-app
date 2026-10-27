import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/color_utils.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../quick_entry/presentation/widgets/category_form_sheet.dart';

class CategoryManagementScreen extends ConsumerStatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  ConsumerState<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends ConsumerState<CategoryManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteCategory(BuildContext context, Category cat) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: Text(
          'Kategori "${cat.name}" akan disembunyikan. Riwayat transaksi lama yang menggunakan kategori ini tetap aman.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = ref.read(databaseProvider);
    await db.softDeleteCategory(cat.id);
    HapticFeedback.lightImpact();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kategori "${cat.name}" berhasil dihapus.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final expenseCategoriesAsync = ref.watch(activeCategoriesStreamProvider('EXPENSE'));
    final incomeCategoriesAsync = ref.watch(activeCategoriesStreamProvider('INCOME'));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.gopayBlueDark,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.gopayBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: const [
            Tab(text: 'Pengeluaran (-)'),
            Tab(text: 'Pemasukan (+)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(
            context,
            categories: expenseCategoriesAsync.value ?? [],
            type: 'EXPENSE',
          ),
          _buildCategoryList(
            context,
            categories: incomeCategoriesAsync.value ?? [],
            type: 'INCOME',
          ),
        ],
      ),
      floatingActionButton: EmilSpringButton(
        onTap: () {
          final currentType = _tabController.index == 0 ? 'EXPENSE' : 'INCOME';
          CategoryFormSheet.show(context, categoryType: currentType);
        },
        child: const FloatingActionButton.extended(
          onPressed: null, // Dikendalikan EmilSpringButton
          backgroundColor: AppColors.gopayBlue,
          foregroundColor: Colors.white,
          icon: Icon(LucideIcons.plus, size: 18),
          label: Text('Tambah Kategori', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildCategoryList(
    BuildContext context, {
    required List<Category> categories,
    required String type,
  }) {
    if (categories.isEmpty) {
      return EmptyStateWidget(
        title: 'Belum Ada Kategori',
        subtitle: 'Ketuk tombol tambah untuk membuat kategori $type baru.',
        icon: LucideIcons.tag,
        useLottie: false,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      itemCount: categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final cat = categories[index];
        final color = ColorUtils.fromHex(cat.colorHex);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(IconHelper.getIcon(cat.iconName), color: color, size: 20),
                ),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (cat.monthlyBudget != null && cat.monthlyBudget! > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Batas Anggaran: ${CurrencyFormatter.formatRupiah(cat.monthlyBudget!)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.edit2, size: 18, color: AppColors.gopayBlue),
                tooltip: 'Edit Kategori',
                onPressed: () {
                  CategoryFormSheet.show(context, categoryToEdit: cat);
                },
              ),
              IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.coralRed),
                tooltip: 'Hapus Kategori',
                onPressed: () => _deleteCategory(context, cat),
              ),
            ],
          ),
        );
      },
    );
  }
}
