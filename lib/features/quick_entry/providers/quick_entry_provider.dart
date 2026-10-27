import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/budget_alert_checker.dart';
import '../../onboarding/providers/onboarding_provider.dart';

/// Penanda "parameter tidak diisi" pada copyWith, agar field nullable bisa
/// benar-benar dikosongkan dengan mengirim null.
const Object _unset = Object();

class QuickEntryState {
  final String type; // 'EXPENSE', 'INCOME', 'TRANSFER'
  final String rawAmount; // Digits string
  final String? selectedWalletId;
  final String? selectedToWalletId;
  final String? selectedCategoryId;
  final DateTime date;
  final String note;
  final bool isSaving;
  final String? errorMessage;
  final String? receiptPath;
  /// Terisi saat mengedit transaksi yang sudah ada; null berarti transaksi baru.
  final String? editingTransactionId;

  QuickEntryState({
    this.type = 'EXPENSE',
    this.rawAmount = '0',
    this.selectedWalletId,
    this.selectedToWalletId,
    this.selectedCategoryId,
    DateTime? date,
    this.note = '',
    this.receiptPath,
    this.isSaving = false,
    this.errorMessage,
    this.editingTransactionId,
  }) : date = date ?? DateTime.now();

  bool get isEditing => editingTransactionId != null;

  int get amount => int.tryParse(rawAmount) ?? 0;
  bool get canSave {
    if (amount <= 0 || isSaving) return false;
    if (selectedWalletId == null) return false;
    if (type == 'TRANSFER') {
      return selectedToWalletId != null && selectedWalletId != selectedToWalletId;
    } else {
      return selectedCategoryId != null;
    }
  }

  /// Field nullable (dompet, dompet tujuan, kategori, receiptPath) bisa dikosongkan dengan null.
  /// [errorMessage] selalu direset kecuali diisi.
  QuickEntryState copyWith({
    String? type,
    String? rawAmount,
    Object? selectedWalletId = _unset,
    Object? selectedToWalletId = _unset,
    Object? selectedCategoryId = _unset,
    DateTime? date,
    String? note,
    Object? receiptPath = _unset,
    bool? isSaving,
    String? errorMessage,
  }) {
    return QuickEntryState(
      type: type ?? this.type,
      rawAmount: rawAmount ?? this.rawAmount,
      selectedWalletId:
          identical(selectedWalletId, _unset) ? this.selectedWalletId : selectedWalletId as String?,
      selectedToWalletId:
          identical(selectedToWalletId, _unset) ? this.selectedToWalletId : selectedToWalletId as String?,
      selectedCategoryId:
          identical(selectedCategoryId, _unset) ? this.selectedCategoryId : selectedCategoryId as String?,
      date: date ?? this.date,
      note: note ?? this.note,
      receiptPath:
          identical(receiptPath, _unset) ? this.receiptPath : receiptPath as String?,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      editingTransactionId: editingTransactionId,
    );
  }
}

class QuickEntryNotifier extends StateNotifier<QuickEntryState> {
  final Ref _ref;

  QuickEntryNotifier(this._ref) : super(QuickEntryState());

  /// Kategori pertama yang cocok dengan [type], atau null.
  static String? _firstCategoryFor(String type, List<Category> categories) {
    if (type == 'TRANSFER') return null;
    for (final c in categories) {
      if (c.type == type) return c.id;
    }
    return null;
  }

  /// [categories] harus berisi SEMUA kategori aktif (pengeluaran dan pemasukan).
  void initDefaults({
    required List<Wallet> wallets,
    required List<Category> categories,
    String? initialType,
  }) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final lastWalletId = prefs.getString(AppConstants.prefLastUsedWalletId);
    final type = initialType ?? state.type;

    String? defaultWalletId;
    if (lastWalletId != null && wallets.any((w) => w.id == lastWalletId)) {
      defaultWalletId = lastWalletId;
    } else if (wallets.isNotEmpty) {
      defaultWalletId = wallets.first.id;
    }

    String? defaultToWalletId;
    for (final w in wallets) {
      if (w.id != defaultWalletId) {
        defaultToWalletId = w.id;
        break;
      }
    }

    state = state.copyWith(
      type: type,
      selectedWalletId: defaultWalletId,
      selectedToWalletId: defaultToWalletId,
      selectedCategoryId: _firstCategoryFor(type, categories),
    );
  }

  /// Mengisi form dengan data transaksi yang akan diedit.
  void loadForEdit(Transaction tx) {
    state = QuickEntryState(
      type: tx.type,
      rawAmount: tx.amount.toString(),
      selectedWalletId: tx.walletId,
      selectedToWalletId: tx.toWalletId,
      selectedCategoryId: tx.categoryId,
      date: tx.transactionDate,
      note: tx.note ?? '',
      receiptPath: tx.receiptPath,
      editingTransactionId: tx.id,
    );
  }

  /// Mode "Isi Tabungan": transfer dari dompet harian ke kantong tabungan.
  /// Jika belum ada kantong tabungan, tujuan dikosongkan agar tidak salah kirim.
  void initSavingsMode(List<Wallet> wallets) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final lastWalletId = prefs.getString(AppConstants.prefLastUsedWalletId);
    final daily = wallets.where((w) => w.walletType != 'SAVINGS').toList();
    final savings = wallets.where((w) => w.walletType == 'SAVINGS').toList();

    String? source;
    if (lastWalletId != null && daily.any((w) => w.id == lastWalletId)) {
      source = lastWalletId;
    } else if (daily.isNotEmpty) {
      source = daily.first.id;
    }

    state = state.copyWith(
      type: 'TRANSFER',
      selectedWalletId: source,
      selectedToWalletId: savings.isNotEmpty ? savings.first.id : null,
      selectedCategoryId: null,
    );
  }

  /// [categories] harus berisi SEMUA kategori aktif agar kategori tipe baru bisa ditemukan.
  void setType(String newType, List<Category> categories) {
    if (newType == state.type) return;
    state = state.copyWith(
      type: newType,
      selectedCategoryId: _firstCategoryFor(newType, categories),
    );
  }

  void appendKey(String key) {
    var current = state.rawAmount;
    if (current == '0') {
      if (key == '000' || key == '0') return;
      current = key;
    } else {
      if (current.length + key.length > AppConstants.maxInputDigits) return;
      current += key;
    }
    state = state.copyWith(rawAmount: current);
  }

  void backspace() {
    var current = state.rawAmount;
    if (current.length <= 1) {
      current = '0';
    } else {
      current = current.substring(0, current.length - 1);
    }
    state = state.copyWith(rawAmount: current);
  }

  void clearAmount() {
    state = state.copyWith(rawAmount: '0');
  }

  /// Jika dompet asal baru sama dengan dompet tujuan, keduanya ditukar.
  void setWallet(String walletId) {
    if (walletId == state.selectedToWalletId) {
      state = state.copyWith(selectedWalletId: walletId, selectedToWalletId: state.selectedWalletId);
    } else {
      state = state.copyWith(selectedWalletId: walletId);
    }
  }

  /// Jika dompet tujuan baru sama dengan dompet asal, keduanya ditukar.
  void setToWallet(String toWalletId) {
    if (toWalletId == state.selectedWalletId) {
      state = state.copyWith(selectedToWalletId: toWalletId, selectedWalletId: state.selectedToWalletId);
    } else {
      state = state.copyWith(selectedToWalletId: toWalletId);
    }
  }

  void setCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  /// Menampilkan pesan error di dalam sheet (SnackBar tertutup oleh bottom sheet).
  void setError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void setReceiptPath(String? path) {
    state = state.copyWith(receiptPath: path);
  }

  Future<bool> saveTransaction() async {
    if (!state.canSave) return false;

    state = state.copyWith(isSaving: true);
    try {
      final db = _ref.read(databaseProvider);
      final prefs = _ref.read(sharedPreferencesProvider);
      final isTransfer = state.type == 'TRANSFER';

      final tx = TransactionsCompanion(
        id: Value(state.editingTransactionId ?? const Uuid().v4()),
        walletId: Value(state.selectedWalletId!),
        toWalletId: Value(isTransfer ? state.selectedToWalletId : null),
        categoryId: Value(isTransfer ? null : state.selectedCategoryId),
        amount: Value(state.amount),
        type: Value(state.type),
        note: Value(state.note.trim().isEmpty ? null : state.note.trim()),
        transactionDate: Value(state.date),
        receiptPath: Value(state.receiptPath),
        createdAt: Value(DateTime.now()),
      );

      // ACID Transaction (PRD Rule 4) — juga memvalidasi kecocokan kategori & dompet.
      if (state.isEditing) {
        await db.updateTransactionWithRebalance(tx);
      } else {
        await db.createTransaction(tx);
      }

      await prefs.setString(AppConstants.prefLastUsedWalletId, state.selectedWalletId!);

      // Feature 7: Notifikasi anggaran saat mencapai 80%/100%
      if (state.type == 'EXPENSE') {
        _checkBudgetAlerts(db, prefs);
      }

      state = state.copyWith(isSaving: false);
      return true;
    } on DataValidationException catch (e) {
      state = state.copyWith(isSaving: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isSaving: false, errorMessage: 'Gagal menyimpan transaksi. Silakan coba lagi.');
      return false;
    }
  }

  void _checkBudgetAlerts(AppDatabase db, SharedPreferences prefs) {
    // Ambil nilai sekarang: setelah ini sheet bisa tertutup dan provider di-dispose.
    final categoryId = state.selectedCategoryId;
    final txDate = state.date;
    Future.microtask(() => BudgetAlertChecker(db, prefs).check(categoryId: categoryId, transactionDate: txDate));
  }
}

final quickEntryProvider = StateNotifierProvider.autoDispose<QuickEntryNotifier, QuickEntryState>((ref) {
  return QuickEntryNotifier(ref);
});
