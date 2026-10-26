import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_provider.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/utils/color_utils.dart';

class CategoryFormSheet extends ConsumerStatefulWidget {
  final String categoryType; // 'EXPENSE' or 'INCOME'

  const CategoryFormSheet({
    super.key,
    this.categoryType = 'EXPENSE',
  });

  static Future<Category?> show(BuildContext context, {String categoryType = 'EXPENSE'}) {
    return showModalBottomSheet<Category>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryFormSheet(categoryType: categoryType),
    );
  }

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _nameController = TextEditingController();
  String? _errorText;
  bool _isSaving = false;
  String _selectedIcon = 'tag';
  String _selectedColor = '#F04438';

  final List<String> _colors = [
    '#F04438', // Coral Red
    '#00AA13', // Gojek Green
    '#00AED6', // GoPay Cyan
    '#7C3AED', // Brand Purple
    '#F79009', // Warning Amber
    '#EC4899', // Pink
    '#3B82F6', // Blue
    '#64748B', // Slate
  ];

  final List<String> _icons = [
    'tag',
    'utensils',
    'coffee',
    'car',
    'shopping-bag',
    'receipt',
    'gamepad-2',
    'heart-pulse',
    'book',
    'gift',
    'film',
    'laptop',
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.categoryType == 'EXPENSE' ? '#F04438' : '#00AA13';
    _selectedIcon = widget.categoryType == 'EXPENSE' ? 'tag' : 'banknote';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Nama kategori wajib diisi.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _errorText = null;
      _isSaving = true;
    });
    final db = ref.read(databaseProvider);
    // UUID penuh agar tidak ada risiko tabrakan ID.
    final id = 'cat_custom_${const Uuid().v4()}';

    try {
      await db.insertCategory(
        CategoriesCompanion(
          id: drift.Value(id),
          name: drift.Value(name),
          type: drift.Value(widget.categoryType),
          iconName: drift.Value(_selectedIcon),
          colorHex: drift.Value(_selectedColor),
          isDeleted: const drift.Value(false),
        ),
      );
      final newCat = await db.getCategoryById(id);
      if (mounted) Navigator.of(context).pop(newCat);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = 'Gagal menyimpan kategori. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              Text(
                widget.categoryType == 'EXPENSE'
                    ? 'Tambah Jenis Pengeluaran Baru'
                    : 'Tambah Kategori Pemasukan Baru',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),

              const Text('Nama Kategori', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                inputFormatters: [LengthLimitingTextInputFormatter(AppConstants.maxNameLength)],
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'misal: Kopi & Nongkrong, Bensin, Skincare',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.gopayBlue, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              const Text('Pilih Ikon', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _icons.map((iconName) {
                  final isSelected = _selectedIcon == iconName;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedIcon = iconName);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.gopayBlue : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        IconHelper.getIcon(iconName),
                        color: isSelected ? AppColors.gopayBlue : AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text('Pilih Warna', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: _colors.map((hex) {
                  final color = ColorUtils.fromHex(hex);
                  final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
                  return InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedColor = hex);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppColors.textPrimary : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              if (_errorText != null) ...[
                Text(
                  _errorText!,
                  style: const TextStyle(color: AppColors.coralRed, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gopayBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Simpan Kategori Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
