import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/icon_helper.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../quick_entry/presentation/quick_entry_sheet.dart';

class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key});

  @override
  ConsumerState<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends ConsumerState<TransactionSearchScreen> {
  final _searchController = TextEditingController();
  String _queryText = '';
  String _selectedType = 'ALL'; // 'ALL', 'EXPENSE', 'INCOME', 'TRANSFER'
  String? _selectedWalletId;
  String? _selectedCategoryId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateRangeLabel = 'Semua Waktu';

  /// ID transaksi yang baru di-swipe hapus; disembunyikan sinkron agar Dismissible
  /// langsung keluar dari tree sebelum stream database ter-update.
  final Set<String> _hiddenIds = {};
  Timer? _debounce;
  Stream<List<TransactionItem>>? _stream;
  String? _streamKey;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Membuat stream hanya bila filter berubah, bukan di setiap rebuild.
  Stream<List<TransactionItem>> _searchStream(AppDatabase db) {
    final key = [_queryText.trim(), _selectedType, _selectedWalletId, _selectedCategoryId, _startDate, _endDate].join('|');
    if (_stream == null || key != _streamKey) {
      _streamKey = key;
      _stream = db.watchFilteredTransactions(
        queryText: _queryText.trim().isEmpty ? null : _queryText.trim(),
        type: _selectedType == 'ALL' ? null : _selectedType,
        walletId: _selectedWalletId,
        categoryId: _selectedCategoryId,
        startDate: _startDate,
        endDate: _endDate,
      );
    }
    return _stream!;
  }

  void _setDatePreset(String label, DateTime? start, DateTime? end) {
    HapticFeedback.lightImpact();
    setState(() {
      _dateRangeLabel = label;
      _startDate = start;
      _endDate = end;
    });
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      setState(() {
        _startDate = DateTime(picked.start.year, picked.start.month, picked.start.day, 0, 0, 0);
        _endDate = DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59);
        _dateRangeLabel =
            '${DateFormatter.formatShortDate(_startDate!)} - ${DateFormatter.formatShortDate(_endDate!)}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final walletsAsync = ref.watch(activeWalletsStreamProvider);
    final categoriesAsync = ref.watch(activeCategoriesStreamProvider(null));

    final wallets = walletsAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];

    // Stream transaksi berdasarkan filter aktif
    final searchStream = _searchStream(db);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          onChanged: (val) {
            // Tunggu jeda ketik 300 ms sebelum menjalankan pencarian.
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 300), () {
              if (mounted) setState(() => _queryText = val);
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari catatan, kategori, dompet...',
            hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
            border: InputBorder.none,
            suffixIcon: _queryText.isNotEmpty
                ? IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _queryText = '');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Carousel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Type Filter Pills
                  _buildFilterPill(
                    label: 'Semua',
                    isSelected: _selectedType == 'ALL',
                    onTap: () => setState(() => _selectedType = 'ALL'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Keluar (-)',
                    isSelected: _selectedType == 'EXPENSE',
                    activeColor: AppColors.coralRed,
                    onTap: () => setState(() => _selectedType = 'EXPENSE'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Masuk (+)',
                    isSelected: _selectedType == 'INCOME',
                    activeColor: AppColors.gojekGreen,
                    onTap: () => setState(() => _selectedType = 'INCOME'),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterPill(
                    label: 'Transfer',
                    isSelected: _selectedType == 'TRANSFER',
                    activeColor: AppColors.gopayBlue,
                    onTap: () => setState(() => _selectedType = 'TRANSFER'),
                  ),
                  const SizedBox(width: 12),
                  const SizedBox(
                    height: 20,
                    child: VerticalDivider(color: AppColors.border, width: 1),
                  ),
                  const SizedBox(width: 12),

                  // Date Filter Menu
                  PopupMenuButton<String>(
                    tooltip: 'Filter Tanggal',
                    onSelected: (val) {
                      final now = DateTime.now();
                      if (val == 'all') {
                        _setDatePreset('Semua Waktu', null, null);
                      } else if (val == 'this_month') {
                        final start = DateTime(now.year, now.month, 1);
                        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
                        _setDatePreset('Bulan Ini', start, end);
                      } else if (val == '7_days') {
                        final start = now.subtract(const Duration(days: 7));
                        _setDatePreset('7 Hari Terakhir', start, now);
                      } else if (val == '30_days') {
                        final start = now.subtract(const Duration(days: 30));
                        _setDatePreset('30 Hari Terakhir', start, now);
                      } else if (val == 'custom') {
                        _pickCustomDateRange();
                      }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'all', child: Text('Semua Waktu')),
                      const PopupMenuItem(value: 'this_month', child: Text('Bulan Ini')),
                      const PopupMenuItem(value: '7_days', child: Text('7 Hari Terakhir')),
                      const PopupMenuItem(value: '30_days', child: Text('30 Hari Terakhir')),
                      const PopupMenuItem(value: 'custom', child: Text('Rentang Kustom...')),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _startDate != null ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _startDate != null ? AppColors.gopayBlue : AppColors.border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendar, size: 14, color: _startDate != null ? AppColors.gopayBlue : AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            _dateRangeLabel,
                            style: TextStyle(
                              color: _startDate != null ? AppColors.gopayBlueDark : AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Wallet Filter
                  if (wallets.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String?>(
                      tooltip: 'Filter Dompet',
                      onSelected: (val) {
                        setState(() => _selectedWalletId = val);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('Semua Dompet')),
                        ...wallets.map((w) => PopupMenuItem(value: w.id, child: Text(w.name))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedWalletId != null ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedWalletId != null ? AppColors.gopayBlue : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.wallet, size: 14, color: _selectedWalletId != null ? AppColors.gopayBlue : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _selectedWalletId == null
                                  ? 'Dompet'
                                  : (wallets.firstWhere((w) => w.id == _selectedWalletId, orElse: () => wallets.first).name),
                              style: TextStyle(
                                color: _selectedWalletId != null ? AppColors.gopayBlueDark : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Category Filter
                  if (categories.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String?>(
                      tooltip: 'Filter Kategori',
                      onSelected: (val) {
                        setState(() => _selectedCategoryId = val);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: null, child: Text('Semua Kategori')),
                        ...categories.map((c) => PopupMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _selectedCategoryId != null ? AppColors.gopayBlueLight : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedCategoryId != null ? AppColors.gopayBlue : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.tag, size: 14, color: _selectedCategoryId != null ? AppColors.gopayBlue : AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              _selectedCategoryId == null
                                  ? 'Kategori'
                                  : (categories.firstWhere((c) => c.id == _selectedCategoryId, orElse: () => categories.first).name),
                              style: TextStyle(
                                color: _selectedCategoryId != null ? AppColors.gopayBlueDark : AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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

          // Search Results
          Expanded(
            child: StreamBuilder<List<TransactionItem>>(
              stream: searchStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.gopayBlue));
                }

                final items = snapshot.data!.where((i) => !_hiddenIds.contains(i.transaction.id)).toList();
                if (items.isEmpty) {
                  return const EmptyStateWidget(
                    title: 'Tidak Ada Transaksi',
                    subtitle: 'Coba ubah kata kunci atau sesuaikan filter di atas.',
                    icon: LucideIcons.search,
                    useLottie: false,
                  );
                }

                // Hitung total nominal hasil pencarian
                int totalExpense = 0;
                int totalIncome = 0;
                for (final item in items) {
                  if (item.transaction.type == 'EXPENSE') {
                    totalExpense += item.transaction.amount;
                  } else if (item.transaction.type == 'INCOME') {
                    totalIncome += item.transaction.amount;
                  }
                }

                return Column(
                  children: [
                    // Summary header bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppColors.surfaceElevated,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ditemukan ${items.length} transaksi',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: [
                              if (totalExpense > 0)
                                Text(
                                  '-${CurrencyFormatter.formatRupiah(totalExpense)}',
                                  style: const TextStyle(color: AppColors.coralRed, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              if (totalExpense > 0 && totalIncome > 0)
                                const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                              if (totalIncome > 0)
                                Text(
                                  '+${CurrencyFormatter.formatRupiah(totalIncome)}',
                                  style: const TextStyle(color: AppColors.gojekGreen, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final tx = item.transaction;
                          final isExpense = tx.type == 'EXPENSE';
                          final isIncome = tx.type == 'INCOME';

                          final color = isExpense
                              ? AppColors.coralRed
                              : (isIncome ? AppColors.gojekGreen : AppColors.gopayBlue);

                          IconData iconData = LucideIcons.circleDollarSign;
                          if (item.category != null) {
                            iconData = IconHelper.getIcon(item.category!.iconName);
                          } else if (tx.type == 'TRANSFER') {
                            iconData = LucideIcons.arrowRightLeft;
                          }

                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.coralRed,
                              child: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                            ),
                            onDismissed: (_) async {
                              final messenger = ScaffoldMessenger.of(context);
                              setState(() => _hiddenIds.add(tx.id));
                              Transaction? deleted;
                              try {
                                deleted = await db.deleteTransactionWithRevert(tx.id);
                              } catch (_) {
                                if (mounted) setState(() => _hiddenIds.remove(tx.id));
                                messenger.showSnackBar(const SnackBar(content: Text('Gagal menghapus transaksi.')));
                                return;
                              }
                              if (deleted == null) return;
                              final toRestore = deleted;
                              messenger.clearSnackBars();
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Transaksi dihapus'),
                                  action: SnackBarAction(
                                    label: 'Urungkan',
                                    textColor: AppColors.neonLime,
                                    onPressed: () async {
                                      try {
                                        await db.restoreTransaction(toRestore);
                                      } catch (_) {
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text('Transaksi tidak bisa dipulihkan.')),
                                        );
                                      }
                                      if (mounted) setState(() => _hiddenIds.remove(toRestore.id));
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Material(
                              color: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: InkWell(
                                onTap: () {
                                  // Edit transaksi (Feature 1)
                                  QuickEntrySheet.show(context, editTransaction: tx);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.14),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Center(child: Icon(iconData, color: color, size: 20)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.type == 'TRANSFER'
                                                  ? 'Transfer: ${item.wallet.name} → ${item.toWallet?.name ?? 'Dompet'}'
                                                  : (item.category?.name ?? 'Tanpa Kategori'),
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Text(
                                                  '${DateFormatter.formatShortDate(tx.transactionDate)} • ${item.wallet.name}',
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                ),
                                                if (tx.receiptPath != null) ...[
                                                  const SizedBox(width: 4),
                                                  const Icon(LucideIcons.paperclip, size: 12, color: AppColors.gopayBlue),
                                                ],
                                              ],
                                            ),
                                            if (tx.note != null && tx.note!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                tx.note!,
                                                style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${isExpense ? '-' : (isIncome ? '+' : '')}${CurrencyFormatter.formatRupiah(tx.amount)}',
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    Color activeColor = AppColors.gopayBlue,
    required VoidCallback onTap,
  }) {
    return EmilSpringButton(
      onTap: onTap,
      pressScale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.16) : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
