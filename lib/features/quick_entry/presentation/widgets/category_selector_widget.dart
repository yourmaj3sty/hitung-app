import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/color_utils.dart';

class CategorySelectorWidget extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onAddNewCategory;
  final String transactionType; // 'EXPENSE' or 'INCOME'

  const CategorySelectorWidget({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
    required this.onAddNewCategory,
    this.transactionType = 'EXPENSE',
  });

  @override
  Widget build(BuildContext context) {
    final selectedCategory = categories
            .where((c) => c.id == selectedCategoryId)
            .firstOrNull ??
        (categories.isNotEmpty ? categories.first : null);

    final isExpense = transactionType == 'EXPENSE';
    final titleLabel = isExpense ? 'Jenis / Kategori Pengeluaran' : 'Kategori Pemasukan';

    Color categoryColor = isExpense ? AppColors.coralRed : AppColors.gojekGreen;
    if (selectedCategory != null) {
      try {
        categoryColor = ColorUtils.fromHex(selectedCategory.colorHex);
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Label & "Lihat Semua" Link
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titleLabel,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _showCategoryGridModal(context);
              },
              child: const Row(
                children: [
                  Text(
                    'Pilih Semua',
                    style: TextStyle(
                      color: AppColors.gopayBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(LucideIcons.chevronRight, size: 14, color: AppColors.gopayBlue),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Prominent Selected Category Tile (radius: 16)
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showCategoryGridModal(context);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selectedCategory != null
                    ? categoryColor.withOpacity(0.4)
                    : AppColors.border,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (selectedCategory != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      IconHelper.getIcon(selectedCategory.iconName),
                      color: categoryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedCategory.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isExpense ? 'Ketuk untuk mengganti jenis' : 'Sumber pemasukan',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ganti',
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(LucideIcons.chevronDown, size: 12, color: categoryColor),
                      ],
                    ),
                  ),
                ] else ...[
                  const Expanded(
                    child: Text(
                      'Pilih Jenis Pengeluaran...',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                  const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Quick Category Chips (Fast 1-tap horizontal selector)
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                // Last item: '+ Tambah'
                return ActionChip(
                  avatar: const Icon(LucideIcons.plus, size: 13, color: AppColors.gopayBlue),
                  label: const Text('Kategori Baru'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onAddNewCategory();
                  },
                  backgroundColor: AppColors.gopayBlueLight,
                  labelStyle: const TextStyle(
                    color: AppColors.gopayBlueDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: AppColors.gopayBlue.withOpacity(0.3)),
                  ),
                );
              }

              final cat = categories[index];
              final isSelected = selectedCategoryId == cat.id;
              Color catCol = AppColors.textSecondary;
              try {
                catCol = ColorUtils.fromHex(cat.colorHex);
              } catch (_) {}

              return ChoiceChip(
                avatar: Icon(
                  IconHelper.getIcon(cat.iconName),
                  size: 13,
                  color: isSelected ? Colors.white : catCol,
                ),
                label: Text(cat.name),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    HapticFeedback.lightImpact();
                    onCategorySelected(cat.id);
                  }
                },
                selectedColor: isExpense ? AppColors.coralRed : AppColors.gojekGreen,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : AppColors.border,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCategoryGridModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.70,
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  transactionType == 'EXPENSE'
                      ? 'Pilih Jenis Pengeluaran'
                      : 'Pilih Kategori Pemasukan',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onAddNewCategory();
                  },
                  icon: const Icon(LucideIcons.plus, size: 14, color: AppColors.gopayBlue),
                  label: const Text(
                    'Tambah',
                    style: TextStyle(
                      color: AppColors.gopayBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.05,
                ),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = selectedCategoryId == cat.id;

                  Color catColor = AppColors.gopayBlue;
                  try {
                    catColor = ColorUtils.fromHex(cat.colorHex);
                  } catch (_) {}

                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onCategorySelected(cat.id);
                      Navigator.of(ctx).pop();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? catColor.withOpacity(0.15)
                            : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? catColor : AppColors.border,
                          width: isSelected ? 2.0 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: catColor.withOpacity(0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              IconHelper.getIcon(cat.iconName),
                              color: catColor,
                              size: 19,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected ? catColor : AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
