import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/animations/emil_spring_button.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/rupiah_input_formatter.dart';
import '../../../shared/widgets/empty_state.dart';

final _hiddenRecurringIdsProvider = StateProvider<Set<String>>((ref) => const <String>{});

final recurringTransactionsStreamProvider = StreamProvider<List<RecurringTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchRecurringTransactions();
});

class RecurringTransactionsScreen extends ConsumerWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringTransactionsStreamProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaksi Berulang'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20),
            tooltip: 'Proses Transaksi Jatuh Tempo',
            onPressed: () async {
              HapticFeedback.lightImpact();
              int processedCount;
              try {
                processedCount = await db.processDueRecurringTransactions();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gagal memproses transaksi berulang.')),
                  );
                }
                return;
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(processedCount > 0
                        ? '$processedCount transaksi berulang jatuh tempo berhasil diproses!'
                        : 'Semua transaksi berulang sudah mutakhir.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Terjadi kesalahan: $err')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyStateWidget(
              icon: LucideIcons.repeat,
              title: 'Belum Ada Transaksi Berulang',
              subtitle: 'Buat transaksi otomatis seperti gaji, sewa kos, atau langganan streaming.',
              action: ElevatedButton.icon(
                onPressed: () => _showAddRecurringSheet(context, ref),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Tambah Transaksi Berulang'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gojekGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            );
          }

          // Sembunyikan jadwal yang baru di-swipe secara sinkron agar Dismissible
          // langsung keluar dari tree sebelum stream database ter-update.
          final hidden = ref.watch(_hiddenRecurringIdsProvider);
          items = items.where((i) => !hidden.contains(i.id)).toList();

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildRecurringCard(context, ref, item);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.gojekGreen,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus, size: 20),
        label: const Text('Baru', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showAddRecurringSheet(context, ref),
      ),
    );
  }

  Widget _buildRecurringCard(BuildContext context, WidgetRef ref, RecurringTransaction item) {
    final db = ref.read(databaseProvider);
    final isExpense = item.type == 'EXPENSE';

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.coralRed,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(LucideIcons.trash2, color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Hapus Transaksi Berulang?'),
                content: Text('Jadwal "${item.name}" akan dihapus permanen.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.coralRed),
                    child: const Text('Hapus', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) async {
        final hidden = ref.read(_hiddenRecurringIdsProvider.notifier);
        hidden.state = {...hidden.state, item.id};
        try {
          await db.deleteRecurringTransaction(item.id);
        } catch (_) {
          hidden.state = {...hidden.state}..remove(item.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (isExpense ? AppColors.coralRed : AppColors.gojekGreen).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isExpense ? LucideIcons.arrowUpRight : LucideIcons.arrowDownLeft,
                    color: isExpense ? AppColors.coralRed : AppColors.gojekGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_freqLabel(item.frequency)} • Jatuh tempo: ${DateFormatter.formatShortDate(item.nextDueDate)}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: item.isActive,
                  activeColor: AppColors.gojekGreen,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    db.toggleRecurringActive(item.id, val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.isActive ? 'Status: Aktif' : 'Status: Dinonaktifkan',
                  style: TextStyle(
                    color: item.isActive ? AppColors.gojekGreen : AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatRupiah(item.amount),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isExpense ? AppColors.coralRed : AppColors.gojekGreen,
                    fontFeatures: CurrencyFormatter.tabularFigures,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _freqLabel(String freq) {
    switch (freq) {
      case 'DAILY':
        return 'Setiap Hari';
      case 'WEEKLY':
        return 'Setiap Minggu';
      case 'MONTHLY':
        return 'Setiap Bulan';
      case 'YEARLY':
        return 'Setiap Tahun';
      default:
        return freq;
    }
  }

  void _showAddRecurringSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddRecurringBottomSheet(),
    );
  }
}

class _AddRecurringBottomSheet extends ConsumerStatefulWidget {
  const _AddRecurringBottomSheet();

  @override
  ConsumerState<_AddRecurringBottomSheet> createState() => _AddRecurringBottomSheetState();
}

class _AddRecurringBottomSheetState extends ConsumerState<_AddRecurringBottomSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'EXPENSE';
  String _frequency = 'MONTHLY';
  String? _selectedWalletId;
  String? _selectedCategoryId;
  DateTime _nextDueDate = DateTime.now();
  String? _errorText;
  bool _isSaving = false;

  /// Ganti tipe sekaligus mengosongkan kategori agar kategori tipe lama tidak terbawa.
  void _setType(String type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _selectedCategoryId = null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final wallets = ref.watch(activeWalletsStreamProvider).value ?? [];
    final categories = ref.watch(activeCategoriesStreamProvider(_type)).value ?? [];

    if (_selectedWalletId == null && wallets.isNotEmpty) {
      _selectedWalletId = wallets.first.id;
    }
    if (_selectedCategoryId == null || !categories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: mediaQuery.viewInsets.bottom + 24,
      ),
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
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Tambah Transaksi Berulang',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),

            // Segmented Tipe Transaksi
            Row(
              children: [
                Expanded(
                  child: EmilSpringButton(
                    onTap: () => _setType('EXPENSE'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'EXPENSE' ? AppColors.coralRed.withOpacity(0.15) : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'EXPENSE' ? AppColors.coralRed : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pengeluaran',
                        style: TextStyle(
                          color: _type == 'EXPENSE' ? AppColors.coralRed : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: EmilSpringButton(
                    onTap: () => _setType('INCOME'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'INCOME' ? AppColors.gojekGreen.withOpacity(0.15) : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _type == 'INCOME' ? AppColors.gojekGreen : AppColors.border,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Pemasukan',
                        style: TextStyle(
                          color: _type == 'INCOME' ? AppColors.gojekGreen : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Nama Jadwal
            TextField(
              controller: _nameController,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
              decoration: InputDecoration(
                labelText: 'Nama Transaksi Berulang',
                hintText: 'Misal: Langganan Spotify, Gaji Kantor, Wifi',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Nominal
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                const RupiahInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Nominal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // Frekuensi
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: InputDecoration(
                labelText: 'Frekuensi Pengulangan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('Harian (Setiap Hari)')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Mingguan (Setiap Minggu)')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Bulanan (Setiap Bulan)')),
                DropdownMenuItem(value: 'YEARLY', child: Text('Tahunan (Setiap Tahun)')),
              ],
              onChanged: (val) => val != null ? setState(() => _frequency = val) : null,
            ),
            const SizedBox(height: 14),

            // Dompet
            DropdownButtonFormField<String>(
              value: _selectedWalletId,
              decoration: InputDecoration(
                labelText: 'Dompet Asal',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: wallets.map((w) {
                return DropdownMenuItem(value: w.id, child: Text(w.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedWalletId = val),
            ),
            const SizedBox(height: 14),

            // Kategori (mengikuti tipe yang dipilih)
            DropdownButtonFormField<String>(
              key: ValueKey('recurring_category_$_type'),
              value: _selectedCategoryId,
              decoration: InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: categories.map((c) {
                return DropdownMenuItem(value: c.id, child: Text(c.name));
              }).toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 14),

            // Tanggal Mulai / Jatuh Tempo
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _nextDueDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _nextDueDate = picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal Mulai Jatuh Tempo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: const Icon(LucideIcons.calendar, size: 18),
                ),
                child: Text(DateFormatter.formatShortDate(_nextDueDate)),
              ),
            ),
            const SizedBox(height: 20),

            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: const TextStyle(color: AppColors.coralRed, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
            ],

            // Tombol Simpan
            EmilSpringButton(
              onTap: () async {
                final name = _nameController.text.trim();
                final rawAmount = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
                final amount = int.tryParse(rawAmount) ?? 0;

                if (_isSaving) return;
                if (name.isEmpty || amount <= 0 || _selectedWalletId == null || _selectedCategoryId == null) {
                  setState(() => _errorText = 'Lengkapi nama, nominal, dompet, dan kategori terlebih dahulu.');
                  return;
                }
                setState(() {
                  _errorText = null;
                  _isSaving = true;
                });

                final db = ref.read(databaseProvider);
                try {
                await db.insertRecurringTransaction(
                  RecurringTransactionsCompanion(
                    id: drift.Value(const Uuid().v4()),
                    name: drift.Value(name),
                    amount: drift.Value(amount),
                    type: drift.Value(_type),
                    walletId: drift.Value(_selectedWalletId!),
                    categoryId: drift.Value(_selectedCategoryId),
                    frequency: drift.Value(_frequency),
                    nextDueDate: drift.Value(_nextDueDate),
                    isActive: const drift.Value(true),
                    createdAt: drift.Value(DateTime.now()),
                  ),
                );
                } on DataValidationException catch (e) {
                  setState(() {
                    _isSaving = false;
                    _errorText = e.message;
                  });
                  return;
                } catch (_) {
                  setState(() {
                    _isSaving = false;
                    _errorText = 'Gagal menyimpan jadwal. Silakan coba lagi.';
                  });
                  return;
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.gojekGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Simpan Transaksi Berulang',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
