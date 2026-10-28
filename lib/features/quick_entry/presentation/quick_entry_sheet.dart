import 'package:flutter/material.dart';
import 'package:universal_io/io.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/receipt_storage_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/categorized_wallet_picker.dart';
import '../../../shared/widgets/formatted_amount_text.dart';
import '../../wallets/presentation/wallet_form_sheet.dart';
import '../providers/quick_entry_provider.dart';
import 'widgets/category_form_sheet.dart';
import 'widgets/category_selector_widget.dart';
import 'widgets/numpad_widget.dart';

class QuickEntrySheet extends ConsumerStatefulWidget {
  final String? initialType;
  final bool isSavingsMode;
  /// Jika diisi, sheet berjalan dalam mode edit untuk transaksi ini.
  final Transaction? editTransaction;

  const QuickEntrySheet({
    super.key,
    this.initialType,
    this.isSavingsMode = false,
    this.editTransaction,
  });

  static Future<void> show(
    BuildContext context, {
    String? initialType,
    bool isSavingsMode = false,
    Transaction? editTransaction,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickEntrySheet(
        initialType: initialType,
        isSavingsMode: isSavingsMode,
        editTransaction: editTransaction,
      ),
    );
  }

  @override
  ConsumerState<QuickEntrySheet> createState() => _QuickEntrySheetState();
}

class _QuickEntrySheetState extends ConsumerState<QuickEntrySheet> {
  late final _noteController = TextEditingController(text: widget.editTransaction?.note ?? '');
  bool _defaultsInitialized = false;
  bool _isSuccess = false;

  /// Foto struk yang disalin selama sheet ini terbuka. Yang tidak jadi dipakai dihapus
  /// agar tidak menumpuk file yatim di penyimpanan.
  final List<String> _sessionReceipts = [];
  String? _savedReceipt;

  @override
  void dispose() {
    _noteController.dispose();
    _cleanupReceipts();
    super.dispose();
  }

  void _cleanupReceipts() {
    final storage = ReceiptStorageService();
    for (final path in _sessionReceipts) {
      if (path != _savedReceipt) storage.deleteReceipt(path);
    }
    // Saat edit, struk lama yang diganti/dihapus ikut dibersihkan setelah tersimpan.
    final original = widget.editTransaction?.receiptPath;
    if (_isSuccess && original != null && original != _savedReceipt) {
      storage.deleteReceipt(original);
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final notifier = ref.read(quickEntryProvider.notifier);
    try {
      final picker = ImagePicker();
      // Batasi resolusi agar ukuran file wajar (struk tetap terbaca).
      final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600, maxHeight: 1600);
      if (picked != null) {
        final savedPath = await ReceiptStorageService().saveReceipt(picked.path);
        _sessionReceipts.add(savedPath);
        notifier.setReceiptPath(savedPath);
      }
    } catch (_) {
      if (mounted) {
        notifier.setError(source == ImageSource.camera
            ? 'Kamera tidak bisa dibuka. Periksa izin kamera atau pilih dari galeri.'
            : 'Gagal mengambil foto dari galeri.');
      }
    }
  }

  void _showReceiptOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.camera, color: AppColors.gopayBlue),
                title: const Text('Ambil Foto Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceipt(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppColors.gojekGreen),
                title: const Text('Pilih dari Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickReceipt(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final height = mediaQuery.size.height * 0.90;
    // Saat keyboard (untuk catatan) terbuka, numpad disembunyikan dan konten
    // diberi ruang setinggi keyboard agar kolom catatan tidak tertutup.
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = keyboardInset > 0;
    final state = ref.watch(quickEntryProvider);
    final notifier = ref.read(quickEntryProvider.notifier);

    final walletsAsync = ref.watch(activeWalletsStreamProvider);
    // Selalu ambil SEMUA kategori aktif, lalu saring di UI. Dengan begitu saat tipe
    // diganti, kategori milik tipe baru langsung tersedia untuk dipilih otomatis.
    final allCategoriesAsync = ref.watch(activeCategoriesStreamProvider(null));

    final wallets = walletsAsync.value ?? [];
    final allCategories = allCategoriesAsync.value ?? [];
    final categories = allCategories.where((c) => c.type == state.type).toList();

    if (!_defaultsInitialized && wallets.isNotEmpty && allCategoriesAsync.hasValue) {
      _defaultsInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.editTransaction != null) {
          notifier.loadForEdit(widget.editTransaction!);
        } else if (widget.isSavingsMode) {
          notifier.initSavingsMode(wallets);
        } else {
          notifier.initDefaults(
            wallets: wallets,
            categories: allCategories,
            initialType: widget.initialType,
          );
        }
      });
    }

    return Container(
      height: height,
      padding: EdgeInsets.only(bottom: keyboardInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Mode / Segmented Control
            if (widget.isSavingsMode) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gopayBlueLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.gopayBlue.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.sparkles, color: AppColors.gopayBlue, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Isi Kantong Tabungan (✦)',
                        style: TextStyle(
                          color: AppColors.gopayBlueDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              if (state.isEditing)
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    'Edit Transaksi',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Row(
                    children: [
                      _buildTypeTab('EXPENSE', 'Catat Keluar (-)', AppColors.coralRed, state.type, () {
                        HapticFeedback.lightImpact();
                        notifier.setType('EXPENSE', allCategories);
                      }),
                      _buildTypeTab('INCOME', 'Catat Masuk (+)', AppColors.gojekGreen, state.type, () {
                        HapticFeedback.lightImpact();
                        notifier.setType('INCOME', allCategories);
                      }),
                      _buildTypeTab('TRANSFER', 'Pindah Dana', AppColors.gopayBlue, state.type, () {
                        HapticFeedback.lightImpact();
                        notifier.setType('TRANSFER', allCategories);
                      }),
                    ],
                  ),
                ),
              ),
            ],

            // Nominal Display & Selectors
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    // Formatted Amount Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.center,
                      child: FormattedAmountText(
                        amount: state.amount,
                        includeSymbol: true,
                        animate: false, // Instantaneous for fast numpad entry
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: state.type == 'EXPENSE'
                              ? AppColors.coralRed
                              : state.type == 'INCOME'
                                  ? AppColors.gojekGreen
                                  : AppColors.gopayBlue,
                          letterSpacing: -0.5,
                          fontFeatures: CurrencyFormatter.tabularFigures,
                        ),
                      ),
                    ),

                    // 1. Pemilihan Dompet Menggunakan Dropdown dan Categorized
                    if (state.type == 'TRANSFER') ...[
                      Row(
                        children: [
                          // Dompet Asal (Categorized)
                          Expanded(
                            child: CategorizedWalletPicker(
                              label: widget.isSavingsMode ? 'Sumber Dana' : 'Dari Dompet',
                              selectedWalletId: state.selectedWalletId,
                              wallets: widget.isSavingsMode
                                  ? wallets.where((w) => w.walletType != 'SAVINGS').toList()
                                  : wallets,
                              isCompact: true,
                              onChanged: (id) => id != null ? notifier.setWallet(id) : null,
                              onAddNewWallet: () => WalletFormSheet.show(context),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(LucideIcons.arrowRight, color: AppColors.textSecondary, size: 16),
                          ),
                          // Dompet Tujuan (Categorized)
                          Expanded(
                            child: CategorizedWalletPicker(
                              label: widget.isSavingsMode ? 'Kantong Target' : 'Ke Dompet',
                              selectedWalletId: state.selectedToWalletId,
                              wallets: widget.isSavingsMode
                                  ? wallets.where((w) => w.walletType == 'SAVINGS').toList()
                                  : wallets.where((w) => w.id != state.selectedWalletId).toList(),
                              isCompact: true,
                              onChanged: (id) => id != null ? notifier.setToWallet(id) : null,
                              onAddNewWallet: () => WalletFormSheet.show(
                                context,
                                initialIsSavings: widget.isSavingsMode,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Single Wallet Selector (Categorized Dropdown)
                      CategorizedWalletPicker(
                        label: 'Pilih Dompet / Sumber Dana',
                        selectedWalletId: state.selectedWalletId,
                        wallets: wallets,
                        onChanged: (id) => id != null ? notifier.setWallet(id) : null,
                        onAddNewWallet: () => WalletFormSheet.show(context),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // 2. Pemilihan Jenis / Kategori Pengeluaran (Dedicated Category Selector)
                    if (state.type != 'TRANSFER') ...[
                      CategorySelectorWidget(
                        categories: categories,
                        selectedCategoryId: state.selectedCategoryId,
                        transactionType: state.type,
                        onCategorySelected: (catId) {
                          notifier.setCategory(catId);
                        },
                        onAddNewCategory: () async {
                          final newCat = await CategoryFormSheet.show(
                            context,
                            categoryType: state.type,
                          );
                          if (newCat != null) {
                            notifier.setCategory(newCat.id);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Date & Note Row
                    Row(
                      children: [
                        // Date Selector Button (radius: 12)
                        InkWell(
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: state.date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              notifier.setDate(DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                state.date.hour,
                                state.date.minute,
                              ));
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  DateFormatter.formatShortDate(state.date),
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Note Input Field
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            onChanged: notifier.setNote,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: widget.isSavingsMode
                                  ? 'Catatan tabungan (opsional)'
                                  : (state.type == 'EXPENSE'
                                      ? 'Keterangan pengeluaran...'
                                      : 'Catatan opsional...'),
                              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              prefixIcon: const Icon(LucideIcons.pencil, size: 14, color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.surfaceElevated,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppColors.gopayBlue),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // 3. Lampiran Foto Struk (Feature 10)
                    if (state.receiptPath != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                File(state.receiptPath!),
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.border,
                                  child: const Icon(LucideIcons.fileWarning, size: 20, color: AppColors.textMuted),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Foto Struk Terlampir',
                                    style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Tersimpan aman di penyimpanan lokal',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.coralRed),
                              onPressed: () {
                                notifier.setReceiptPath(null);
                              },
                              tooltip: 'Hapus Struk',
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: () => _showReceiptOptions(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.camera, size: 16, color: AppColors.textSecondary),
                              SizedBox(width: 8),
                              Text(
                                '+ Lampirkan Foto Struk (Opsional)',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Custom Numpad & Save Button Area
            Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border, width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isKeyboardOpen) ...[
                    NumpadWidget(
                      onKeyPressed: notifier.appendKey,
                      onBackspacePressed: notifier.backspace,
                      onClearPressed: notifier.clearAmount,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (state.errorMessage != null) ...[
                    Row(
                      children: [
                        const Icon(LucideIcons.circleAlert, size: 14, color: AppColors.coralRed),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.coralRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  EmilSpringButton(
                    onTap: (state.canSave && !_isSuccess && !state.isSaving)
                        ? () async {
                            final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
                            HapticFeedback.mediumImpact();
                            final receiptAtSave = state.receiptPath;
                            final success = await notifier.saveTransaction();
                            if (success && mounted) {
                              _savedReceipt = receiptAtSave;
                              setState(() => _isSuccess = true);
                              HapticFeedback.lightImpact();
                              await Future.delayed(Duration(milliseconds: reduceMotion ? 100 : 320));
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            }
                          }
                        : null,
                    pressScale: 0.95,
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: !state.canSave
                            ? AppColors.border
                            : widget.isSavingsMode
                                ? AppColors.gopayBlue
                                : state.type == 'EXPENSE'
                                    ? AppColors.coralRed
                                    : state.type == 'INCOME'
                                        ? AppColors.gojekGreen
                                        : AppColors.gopayBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: _isSuccess
                          ? SizedBox(
                              width: 32,
                              height: 32,
                              child: Lottie.asset(
                                'assets/lottie/success_check.json',
                                repeat: false,
                                errorBuilder: (_, __, ___) => const Icon(
                                  LucideIcons.check,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            )
                          : state.isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  state.isEditing
                                      ? 'Simpan Perubahan'
                                      : widget.isSavingsMode
                                      ? 'Simpan ke Tabungan (✦)'
                                      : (state.type == 'EXPENSE'
                                          ? 'Simpan Pengeluaran'
                                          : 'Simpan Transaksi'),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: state.canSave ? Colors.white : AppColors.textMuted,
                                  ),
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeTab(
    String type,
    String label,
    Color activeColor,
    String currentType,
    VoidCallback onTap,
  ) {
    final isSelected = type == currentType;
    return Expanded(
      child: EmilSpringButton(
        onTap: onTap,
        pressScale: 0.95,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withOpacity(0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor : Colors.transparent,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
