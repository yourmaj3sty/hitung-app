import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/hitung_logo_widget.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../quick_entry/presentation/quick_entry_sheet.dart';
import '../providers/dashboard_provider.dart';
import '../../wallets/presentation/wallet_form_sheet.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../search/presentation/transaction_search_screen.dart';
import 'widgets/balance_summary_card.dart';
import 'widgets/quick_action_bento_bar.dart';
import 'widgets/daily_transaction_group.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
        if (reduceMotion) {
          _entranceController.value = 1.0;
        } else {
          _entranceController.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateFilterProvider);
    final selectedWalletId = ref.watch(selectedWalletFilterProvider);

    final walletsAsync = ref.watch(activeWalletsStreamProvider);
    final wallets = walletsAsync.value ?? [];

    final dailyGroups = ref.watch(groupedDashboardTransactionsProvider);
    final summary = ref.watch(monthlySummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        // 1. Top App Bar: HitungLogoWidget (compact + teks 'hitung.')
        // FittedBox mengecilkan logo bila ruang sempit (mis. HP 360dp dengan pemilih
        // bulan + tombol pengaturan), sehingga tidak overflow.
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: HitungLogoWidget(
            size: 32,
            showText: true,
            isCompact: true,
            animate: true,
          ),
        ),
        actions: [
          // Pemilih bulan berbentuk rounded pill (< Okt 2026 >)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.chevronLeft, size: 16, color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(selectedDateFilterProvider.notifier).state = DateTime(
                      selectedDate.year,
                      selectedDate.month - 1,
                      1,
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    DateFormatter.formatMonthYear(selectedDate),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textPrimary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(selectedDateFilterProvider.notifier).state = DateTime(
                      selectedDate.year,
                      selectedDate.month + 1,
                      1,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Tombol Cari Transaksi (Feature 4)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.search, color: AppColors.textPrimary, size: 18),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TransactionSearchScreen()),
              );
            },
            tooltip: 'Cari Transaksi',
          ),
          const SizedBox(width: 4),
          // Tombol Pengaturan
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.settings, color: AppColors.textPrimary, size: 18),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Pengaturan',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Hero Balance Container (Satu Kartu Besar radius: 24)
                      BalanceSummaryCard(
                        wallets: wallets,
                        monthlySummary: summary,
                        selectedWalletId: selectedWalletId,
                        onSelectWallet: (id) {
                          ref.read(selectedWalletFilterProvider.notifier).state = id;
                        },
                        onAddWallet: () => WalletFormSheet.show(context),
                      ),
                      const SizedBox(height: 14),

                      // 3. Quick Action Bento Bar (4 Tombol radius: 16)
                      QuickActionBentoBar(
                        onExpense: () => QuickEntrySheet.show(context, initialType: 'EXPENSE'),
                        onIncome: () => QuickEntrySheet.show(context, initialType: 'INCOME'),
                        onTransfer: () => QuickEntrySheet.show(context, initialType: 'TRANSFER'),
                        onSavings: () => QuickEntrySheet.show(context, isSavingsMode: true),
                      ),
                      const SizedBox(height: 18),

                      // Section Title Aktivitas Transaksi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Aktivitas Transaksi',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (selectedWalletId != null)
                            GestureDetector(
                              onTap: () {
                                ref.read(selectedWalletFilterProvider.notifier).state = null;
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.gopayBlueLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      'Filter Aktif',
                                      style: TextStyle(
                                        color: AppColors.gopayBlue,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(LucideIcons.x, size: 12, color: AppColors.gopayBlue),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),

              // 4. Grouped Daily Transaction Cards (radius: 20)
              if (dailyGroups.isEmpty) ...[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyStateWidget(
                    icon: LucideIcons.receipt,
                    title: 'Belum Ada Transaksi',
                    subtitle: 'Ketuk tombol aksi cepat di atas untuk mencatat pengeluaran atau pemasukan.',
                    action: ElevatedButton.icon(
                      onPressed: () => QuickEntrySheet.show(context, initialType: 'EXPENSE'),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Catat Sekarang'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gojekGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
              ] else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final group = dailyGroups[index];
                        return DailyTransactionGroupWidget(
                          dailyGroup: group,
                          onDelete: (item) => _deleteWithUndo(context, ref, item),
                          onTap: (item) => QuickEntrySheet.show(context, editTransaction: item.transaction),
                        );
                      },
                      childCount: dailyGroups.length,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 88),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Menghapus transaksi dengan opsi Urungkan.
  /// ID disembunyikan secara sinkron dulu agar Dismissible langsung keluar dari tree
  /// (mencegah error "A dismissed Dismissible widget is still part of the tree").
  Future<void> _deleteWithUndo(BuildContext context, WidgetRef ref, TransactionItem item) async {
    final id = item.transaction.id;
    final db = ref.read(databaseProvider);
    final hidden = ref.read(pendingDeletedTxIdsProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    hidden.state = {...hidden.state, id};
    void unhide() => hidden.state = {...hidden.state}..remove(id);

    Transaction? deletedTx;
    try {
      deletedTx = await db.deleteTransactionWithRevert(id);
    } catch (_) {
      unhide();
      messenger.showSnackBar(const SnackBar(content: Text('Gagal menghapus transaksi.')));
      return;
    }
    if (deletedTx == null) return;
    final txToRestore = deletedTx;

    final label = item.category?.name ?? (item.transaction.type == 'TRANSFER' ? 'transfer' : 'tersebut');
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 4),
        content: Text('Transaksi $label berhasil dihapus.'),
        action: SnackBarAction(
          label: 'Urungkan (Undo)',
          textColor: AppColors.electricEmerald,
          onPressed: () async {
            try {
              await db.restoreTransaction(txToRestore);
            } catch (_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('Transaksi tidak bisa dipulihkan.')),
              );
            } finally {
              unhide();
            }
          },
        ),
      ),
    );
  }
}
