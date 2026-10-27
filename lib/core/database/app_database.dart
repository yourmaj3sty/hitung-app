import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../constants/app_constants.dart';
import '../utils/color_utils.dart';
import 'data_exceptions.dart';
import 'seed_data.dart';

export 'data_exceptions.dart';

part 'app_database.g.dart';

// --- TABLE DEFINITIONS (According to PRD & Upgrade v2.0) ---

class Wallets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  IntColumn get initialBalance => integer().withDefault(const Constant(0))();
  IntColumn get currentBalance => integer().withDefault(const Constant(0))();
  TextColumn get iconName => text()(); // Nama ikon Lucide
  TextColumn get colorHex => text()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  // Kolom Baru v2.0 (Fitur Tabungan & Preset Institusi)
  TextColumn get walletType => text().withDefault(const Constant('E_WALLET'))(); // 'BANK', 'E_WALLET', 'SAVINGS', 'CASH'
  TextColumn get institutionCode => text().withDefault(const Constant('CUSTOM'))(); // 'BCA', 'JAGO', 'GOPAY', dll.
  IntColumn get targetAmount => integer().nullable()(); // Target tabungan jika walletType == 'SAVINGS'

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get type => text()(); // 'EXPENSE' atau 'INCOME'
  TextColumn get iconName => text()();
  TextColumn get colorHex => text()();
  IntColumn get monthlyBudget => integer().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get toWalletId => text().nullable().references(Wallets, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get amount => integer()(); // Wajib > 0
  TextColumn get type => text()(); // 'EXPENSE', 'INCOME', 'TRANSFER'
  TextColumn get note => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get receiptPath => text().nullable()(); // Lampiran foto struk lokal (Feature 10)

  @override
  Set<Column> get primaryKey => {id};
}

class RecurringTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  IntColumn get amount => integer()();
  TextColumn get type => text()(); // 'EXPENSE', 'INCOME', 'TRANSFER'
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get toWalletId => text().nullable().references(Wallets, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get frequency => text()(); // 'DAILY', 'WEEKLY', 'MONTHLY'
  DateTimeColumn get nextDueDate => dateTime()();
  DateTimeColumn get lastGeneratedDate => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  /// Tanggal acuan (1-31) untuk jadwal bulanan, agar jadwal tanggal 31 tidak
  /// permanen bergeser ke 28 setelah melewati Februari.
  IntColumn get anchorDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// Data class to join transaction with its wallet and category
class TransactionItem {
  final Transaction transaction;
  final Wallet wallet;
  final Wallet? toWallet;
  final Category? category;

  TransactionItem({
    required this.transaction,
    required this.wallet,
    this.toWallet,
    this.category,
  });
}

/// Nilai-nilai yang diizinkan untuk kolom teks bertipe enum.
class DbEnums {
  static const transactionTypes = {'EXPENSE', 'INCOME', 'TRANSFER'};
  static const categoryTypes = {'EXPENSE', 'INCOME'};
  static const walletTypes = {'BANK', 'E_WALLET', 'SAVINGS', 'CASH'};
  static const recurringFrequencies = {'DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'};
  static const nameMaxLength = AppConstants.maxNameLength;
}

@DriftDatabase(tables: [Wallets, Categories, Transactions, RecurringTransactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Migrasi aman v1 -> v2: tambah kolom walletType, institutionCode, targetAmount
            await m.addColumn(wallets, wallets.walletType);
            await m.addColumn(wallets, wallets.institutionCode);
            await m.addColumn(wallets, wallets.targetAmount);
          }
          if (from < 3) {
            // Migrasi aman v2 -> v3: tambah kolom receiptPath & tabel recurringTransactions
            await m.addColumn(transactions, transactions.receiptPath);
            await m.createTable(recurringTransactions); // sudah memuat kolom anchorDay
          }
          if (from == 3) {
            await m.addColumn(recurringTransactions, recurringTransactions.anchorDay);
          }
        },
        beforeOpen: (details) async {
          // SQLite tidak menegakkan REFERENCES tanpa pragma ini.
          await customStatement('PRAGMA foreign_keys = ON');
          // Index untuk query dashboard, analitik, dan filter dompet.
          // IF NOT EXISTS membuatnya aman dijalankan di setiap pembukaan database.
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions (transaction_date)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_wallet ON transactions (wallet_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_to_wallet ON transactions (to_wallet_id)');
          await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions (category_id)');
        },
      );

  // --- WALLET QUERIES ---

  Stream<List<Wallet>> watchActiveWallets({String? walletType}) {
    final query = select(wallets)..where((tbl) => tbl.isArchived.equals(false));
    if (walletType != null) {
      query.where((tbl) => tbl.walletType.equals(walletType));
    }
    query.orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.watch();
  }

  Future<List<Wallet>> getActiveWallets({String? walletType}) {
    final query = select(wallets)..where((tbl) => tbl.isArchived.equals(false));
    if (walletType != null) {
      query.where((tbl) => tbl.walletType.equals(walletType));
    }
    query.orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]);
    return query.get();
  }

  Future<Wallet?> getWalletById(String id) {
    return (select(wallets)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertWallet(WalletsCompanion wallet) {
    return into(wallets).insert(wallet);
  }

  Future<bool> updateWallet(WalletsCompanion wallet) {
    return update(wallets).replace(wallet);
  }

  // Soft delete wallet (PRD Rule 5: No Hard Delete on Referenced Entities)
  Future<int> archiveWallet(String id) {
    return (update(wallets)..where((tbl) => tbl.id.equals(id))).write(
      const WalletsCompanion(isArchived: Value(true)),
    );
  }

  // Pulihkan dompet yang diarsipkan (Feature 3)
  Future<int> unarchiveWallet(String id) {
    return (update(wallets)..where((tbl) => tbl.id.equals(id))).write(
      const WalletsCompanion(isArchived: Value(false)),
    );
  }

  Stream<List<Wallet>> watchArchivedWallets() {
    return (select(wallets)
          ..where((tbl) => tbl.isArchived.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .watch();
  }

  Future<List<Wallet>> getArchivedWallets() {
    return (select(wallets)
          ..where((tbl) => tbl.isArchived.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.createdAt)]))
        .get();
  }

  /// Penyesuaian saldo secara atomik: mengoreksi selisih dengan saldo bank/rekening asli (Feature 3).
  /// Menghitung selisih (delta = actual - current) dan membuat transaksi pencatatan audit.
  Future<void> adjustWalletBalance({
    required String walletId,
    required int actualBalance,
    String? note,
  }) {
    return transaction(() async {
      final wallet = await getWalletById(walletId);
      if (wallet == null) throw const DataValidationException('Dompet tidak ditemukan.');

      final delta = actualBalance - wallet.currentBalance;
      if (delta == 0) return; // Tidak ada selisih yang perlu disesuaikan

      final isPositive = delta > 0;
      final txType = isPositive ? 'INCOME' : 'EXPENSE';
      final txAmount = delta.abs();

      final tx = TransactionsCompanion(
        id: Value('adj_${const Uuid().v4()}'),
        walletId: Value(walletId),
        toWalletId: const Value(null),
        categoryId: const Value(null),
        amount: Value(txAmount),
        type: Value(txType),
        note: Value(note ?? 'Penyesuaian Saldo (${isPositive ? '+' : '-'}$txAmount)'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      );

      await into(transactions).insert(tx);
      await customUpdate(
        'UPDATE wallets SET current_balance = ? WHERE id = ?',
        variables: [Variable.withInt(actualBalance), Variable.withString(walletId)],
        updates: {wallets},
        updateKind: UpdateKind.update,
      );
    });
  }

  // --- CATEGORY QUERIES ---

  Stream<List<Category>> watchActiveCategories({String? type}) {
    final query = select(categories)..where((tbl) => tbl.isDeleted.equals(false));
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    return query.watch();
  }

  Future<List<Category>> getActiveCategories({String? type}) {
    final query = select(categories)..where((tbl) => tbl.isDeleted.equals(false));
    if (type != null) {
      query.where((tbl) => tbl.type.equals(type));
    }
    return query.get();
  }

  Future<Category?> getCategoryById(String id) {
    return (select(categories)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
  }

  Future<int> insertCategory(CategoriesCompanion category) {
    return into(categories).insert(category);
  }

  Future<bool> updateCategory(CategoriesCompanion category) {
    return update(categories).replace(category);
  }

  // Soft delete category (PRD Rule 5)
  Future<int> softDeleteCategory(String id) {
    return (update(categories)..where((tbl) => tbl.id.equals(id))).write(
      const CategoriesCompanion(isDeleted: Value(true)),
    );
  }

  Future<int> updateCategoryBudget(String id, int? budget) {
    return (update(categories)..where((tbl) => tbl.id.equals(id))).write(
      CategoriesCompanion(monthlyBudget: Value(budget)),
    );
  }

  // --- ACID TRANSACTION MUTATIONS (PRD Rule 4) ---

  /// Menambah/mengurangi saldo dengan satu pernyataan SQL (tanpa baca-lalu-tulis).
  /// Mengembalikan jumlah baris yang berubah (0 jika dompet tidak ada).
  Future<int> _adjustBalance(String walletId, int delta) {
    return customUpdate(
      'UPDATE wallets SET current_balance = current_balance + ? WHERE id = ?',
      variables: [Variable.withInt(delta), Variable.withString(walletId)],
      updates: {wallets},
      updateKind: UpdateKind.update,
    );
  }

  Future<void> _adjustBalanceOrThrow(String walletId, int delta, String notFoundMessage) async {
    final changed = await _adjustBalance(walletId, delta);
    if (changed == 0) throw DataValidationException(notFoundMessage);
  }

  /// Memastikan transaksi valid sebelum disimpan. Melempar [DataValidationException].
  Future<void> _validateTransaction(TransactionsCompanion tx) async {
    if (!tx.amount.present || !tx.type.present || !tx.walletId.present) {
      throw const DataValidationException('Data transaksi tidak lengkap.');
    }
    final amount = tx.amount.value;
    final type = tx.type.value;

    if (amount <= 0 || amount > AppConstants.maxInputAmount) {
      throw const DataValidationException('Nominal transaksi harus lebih dari Rp 0 dan maksimal 12 digit.');
    }
    if (!DbEnums.transactionTypes.contains(type)) {
      throw DataValidationException('Tipe transaksi "$type" tidak dikenal.');
    }

    final categoryId = tx.categoryId.present ? tx.categoryId.value : null;
    final toWalletId = tx.toWalletId.present ? tx.toWalletId.value : null;

    if (type == 'TRANSFER') {
      if (toWalletId == null) {
        throw const DataValidationException('Dompet tujuan wajib diisi untuk transfer.');
      }
      if (toWalletId == tx.walletId.value) {
        throw const DataValidationException('Dompet asal dan dompet tujuan tidak boleh sama.');
      }
    } else if (categoryId != null) {
      final category = await getCategoryById(categoryId);
      if (category == null) {
        throw const DataValidationException('Kategori tidak ditemukan.');
      }
      if (category.type != type) {
        throw const DataValidationException('Kategori tidak sesuai dengan jenis transaksi.');
      }
    }
  }

  // Insert transaction and atomically adjust currentBalance on wallets
  Future<void> createTransaction(TransactionsCompanion tx) {
    return transaction(() async {
      await _validateTransaction(tx);

      final type = tx.type.value;
      final amount = tx.amount.value;
      final walletId = tx.walletId.value;

      // Normalisasi: transfer tidak punya kategori, pemasukan/pengeluaran tidak punya dompet tujuan.
      final normalized = type == 'TRANSFER'
          ? tx.copyWith(categoryId: const Value(null))
          : tx.copyWith(toWalletId: const Value(null));
      await into(transactions).insert(normalized);

      if (type == 'EXPENSE') {
        await _adjustBalanceOrThrow(walletId, -amount, 'Dompet asal tidak ditemukan.');
      } else if (type == 'INCOME') {
        await _adjustBalanceOrThrow(walletId, amount, 'Dompet asal tidak ditemukan.');
      } else {
        await _adjustBalanceOrThrow(walletId, -amount, 'Dompet asal tidak ditemukan.');
        await _adjustBalanceOrThrow(tx.toWalletId.value!, amount, 'Dompet tujuan tidak ditemukan.');
      }
    });
  }

  // Delete transaction and atomically revert currentBalance on wallets (for swipe-to-delete)
  Future<Transaction?> deleteTransactionWithRevert(String transactionId) {
    return transaction(() async {
      final tx = await (select(transactions)..where((t) => t.id.equals(transactionId))).getSingleOrNull();
      if (tx == null) return null;

      if (tx.type == 'EXPENSE') {
        await _adjustBalance(tx.walletId, tx.amount);
      } else if (tx.type == 'INCOME') {
        await _adjustBalance(tx.walletId, -tx.amount);
      } else if (tx.type == 'TRANSFER') {
        await _adjustBalance(tx.walletId, tx.amount);
        if (tx.toWalletId != null) {
          await _adjustBalance(tx.toWalletId!, -tx.amount);
        }
      }

      await (delete(transactions)..where((t) => t.id.equals(transactionId))).go();
      return tx;
    });
  }

  /// Mengubah transaksi secara atomik: efek saldo lama dibatalkan, data baru divalidasi,
  /// lalu efek saldo baru diterapkan. Jika validasi gagal, semua perubahan dibatalkan.
  /// ID dan waktu pembuatan (createdAt) transaksi asli dipertahankan.
  Future<void> updateTransactionWithRebalance(TransactionsCompanion tx) {
    return transaction(() async {
      final old = await deleteTransactionWithRevert(tx.id.value);
      if (old == null) throw const DataValidationException('Transaksi tidak ditemukan.');
      await createTransaction(tx.copyWith(createdAt: Value(old.createdAt)));
    });
  }

  Future<Transaction?> getTransactionById(String id) {
    return (select(transactions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // Restore deleted transaction (Undo support)
  Future<void> restoreTransaction(Transaction tx) {
    return createTransaction(TransactionsCompanion(
      id: Value(tx.id),
      walletId: Value(tx.walletId),
      toWalletId: Value(tx.toWalletId),
      categoryId: Value(tx.categoryId),
      amount: Value(tx.amount),
      type: Value(tx.type),
      note: Value(tx.note),
      transactionDate: Value(tx.transactionDate),
      receiptPath: Value(tx.receiptPath),
      createdAt: Value(tx.createdAt),
    ));
  }

  Future<int> getMonthlyExpenseForCategory(String categoryId, DateTime date) async {
    final start = DateTime(date.year, date.month, 1);
    final endExclusive = DateTime(date.year, date.month + 1, 1);
    final sumCol = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(
        transactions.type.equals('EXPENSE') &
        transactions.categoryId.equals(categoryId) &
        transactions.transactionDate.isBiggerOrEqualValue(start) &
        transactions.transactionDate.isSmallerThanValue(endExclusive),
      );
    final result = await query.getSingleOrNull();
    return result?.read(sumCol) ?? 0;
  }

  Future<int> getMonthlyTotalExpense(DateTime date) async {
    final start = DateTime(date.year, date.month, 1);
    final endExclusive = DateTime(date.year, date.month + 1, 1);
    final sumCol = transactions.amount.sum();
    final query = selectOnly(transactions)
      ..addColumns([sumCol])
      ..where(
        transactions.type.equals('EXPENSE') &
        transactions.transactionDate.isBiggerOrEqualValue(start) &
        transactions.transactionDate.isSmallerThanValue(endExclusive),
      );
    final result = await query.getSingleOrNull();
    return result?.read(sumCol) ?? 0;
  }

  // --- REACTIVE DASHBOARD TRANSACTIONS STREAM ---

  /// Transaksi dengan tanggal di rentang [startDate, endDateExclusive).
  /// Dompet tujuan diambil lewat JOIN alias, jadi hanya satu query per emisi.
  Stream<List<TransactionItem>> watchTransactions({
    required DateTime startDate,
    required DateTime endDateExclusive,
    String? walletId,
  }) {
    final toWallets = alias(wallets, 'to_wallet');
    final query = select(transactions).join([
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
      leftOuterJoin(toWallets, toWallets.id.equalsExp(transactions.toWalletId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);

    query.where(transactions.transactionDate.isBiggerOrEqualValue(startDate) &
        transactions.transactionDate.isSmallerThanValue(endDateExclusive));

    if (walletId != null && walletId.isNotEmpty) {
      query.where(
        transactions.walletId.equals(walletId) | transactions.toWalletId.equals(walletId),
      );
    }

    query.orderBy([
      OrderingTerm.desc(transactions.transactionDate),
      OrderingTerm.desc(transactions.createdAt),
    ]);

    return query.watch().map((rows) => [
          for (final row in rows)
            TransactionItem(
              transaction: row.readTable(transactions),
              wallet: row.readTable(wallets),
              toWallet: row.readTableOrNull(toWallets),
              category: row.readTableOrNull(categories),
            ),
        ]);
  }

  /// Seluruh pengeluaran di rentang [start, endExclusive) dari semua dompet.
  Stream<List<Transaction>> watchExpensesBetween(DateTime start, DateTime endExclusive) {
    return (select(transactions)
          ..where((t) =>
              t.type.equals('EXPENSE') &
              t.transactionDate.isBiggerOrEqualValue(start) &
              t.transactionDate.isSmallerThanValue(endExclusive)))
        .watch();
  }

  /// Mencari transaksi berdasarkan kata kunci (catatan, nama kategori, nama dompet)
  /// dan filter opsional (tipe, kategori, dompet, rentang tanggal) (Feature 4).
  Stream<List<TransactionItem>> watchFilteredTransactions({
    String? queryText,
    String? type,
    String? walletId,
    String? categoryId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final toWallets = alias(wallets, 'to_wallet');
    final query = select(transactions).join([
      innerJoin(wallets, wallets.id.equalsExp(transactions.walletId)),
      leftOuterJoin(toWallets, toWallets.id.equalsExp(transactions.toWalletId)),
      leftOuterJoin(categories, categories.id.equalsExp(transactions.categoryId)),
    ]);

    if (startDate != null) {
      query.where(transactions.transactionDate.isBiggerOrEqualValue(startDate));
    }
    if (endDate != null) {
      // endDate dianggap inklusif sampai akhir harinya.
      final endExclusive = DateTime(endDate.year, endDate.month, endDate.day + 1);
      query.where(transactions.transactionDate.isSmallerThanValue(endExclusive));
    }
    if (type != null && type.isNotEmpty && type != 'ALL') {
      query.where(transactions.type.equals(type));
    }
    if (walletId != null && walletId.isNotEmpty) {
      query.where(transactions.walletId.equals(walletId) | transactions.toWalletId.equals(walletId));
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (queryText != null && queryText.trim().isNotEmpty) {
      // instr() dipakai alih-alih LIKE agar karakter % dan _ yang diketik pengguna
      // diperlakukan sebagai teks biasa, bukan wildcard.
      final q = Variable.withString(queryText.trim().toLowerCase());
      Expression<bool> hit(Expression<String> col) =>
          FunctionCallExpression<int>('instr', [col.lower(), q]).isBiggerThanValue(0);
      query.where(
        hit(transactions.note) | hit(categories.name) | hit(wallets.name) | hit(toWallets.name),
      );
    }

    query.orderBy([
      OrderingTerm.desc(transactions.transactionDate),
      OrderingTerm.desc(transactions.createdAt),
    ]);

    return query.watch().map((rows) => [
          for (final row in rows)
            TransactionItem(
              transaction: row.readTable(transactions),
              wallet: row.readTable(wallets),
              toWallet: row.readTableOrNull(toWallets),
              category: row.readTableOrNull(categories),
            ),
        ]);
  }

  // --- RECURRING TRANSACTIONS QUERIES (Feature 6) ---

  Stream<List<RecurringTransaction>> watchRecurringTransactions() {
    return (select(recurringTransactions)
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.nextDueDate)]))
        .watch();
  }

  Future<List<RecurringTransaction>> getActiveRecurringTransactions() {
    return (select(recurringTransactions)
          ..where((t) => t.isActive.equals(true))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.nextDueDate)]))
        .get();
  }

  /// Memvalidasi jadwal berulang. Melempar [DataValidationException].
  Future<void> validateRecurring(RecurringTransactionsCompanion rec) async {
    final name = rec.name.present ? rec.name.value.trim() : '';
    if (name.isEmpty || name.length > 100) {
      throw const DataValidationException('Nama jadwal wajib diisi (maksimal 100 karakter).');
    }
    await _validateTransaction(TransactionsCompanion(
      amount: rec.amount,
      type: rec.type,
      walletId: rec.walletId,
      toWalletId: rec.toWalletId,
      categoryId: rec.categoryId,
    ));
    if (!rec.frequency.present || !DbEnums.recurringFrequencies.contains(rec.frequency.value)) {
      throw const DataValidationException('Frekuensi jadwal tidak valid.');
    }
  }

  Future<int> insertRecurringTransaction(RecurringTransactionsCompanion rec) async {
    await validateRecurring(rec);
    final withAnchor = rec.anchorDay.present ? rec : rec.copyWith(anchorDay: Value(rec.nextDueDate.value.day));
    return into(recurringTransactions).insert(withAnchor);
  }

  Future<bool> updateRecurringTransaction(RecurringTransactionsCompanion rec) {
    return update(recurringTransactions).replace(rec);
  }

  Future<int> deleteRecurringTransaction(String id) {
    return (delete(recurringTransactions)..where((t) => t.id.equals(id))).go();
  }

  Future<int> toggleRecurringActive(String id, bool isActive) {
    return (update(recurringTransactions)..where((t) => t.id.equals(id))).write(
      RecurringTransactionsCompanion(isActive: Value(isActive)),
    );
  }

  /// Tanggal kemunculan berikutnya. Untuk bulanan, [anchorDay] dipakai sebagai acuan
  /// sehingga 31 Jan -> 28 Feb -> 31 Mar -> 30 Apr (tidak terjebak di tanggal 28).
  static DateTime nextOccurrence(DateTime current, String frequency, int anchorDay) {
    switch (frequency) {
      case 'DAILY':
        return DateTime(current.year, current.month, current.day + 1, current.hour, current.minute);
      case 'WEEKLY':
        return DateTime(current.year, current.month, current.day + 7, current.hour, current.minute);
      case 'YEARLY':
        final daysInMonth = DateTime(current.year + 1, current.month + 1, 0).day;
        final day = anchorDay > daysInMonth ? daysInMonth : anchorDay;
        return DateTime(current.year + 1, current.month, day, current.hour, current.minute);
      default: // MONTHLY
        final daysInNext = DateTime(current.year, current.month + 2, 0).day;
        final day = anchorDay > daysInNext ? daysInNext : anchorDay;
        return DateTime(current.year, current.month + 1, day, current.hour, current.minute);
    }
  }

  /// Batas pembuatan transaksi susulan per jadwal dalam sekali proses.
  static const int maxCatchUpPerSchedule = 400;

  /// Memproses transaksi berulang yang jatuh tempo (Feature 6).
  /// - Semua kemunculan yang terlewat dibuat (mis. 3 bulan tidak membuka aplikasi -> 3 transaksi).
  /// - Setiap jadwal diproses dalam transaksinya sendiri. Jadwal yang tidak valid
  ///   (mis. kategori tidak cocok) dinonaktifkan agar tidak memblokir jadwal lain.
  Future<int> processDueRecurringTransactions({DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final dueItems = await (select(recurringTransactions)
          ..where((t) => t.isActive.equals(true) & t.nextDueDate.isSmallerOrEqualValue(reference)))
        .get();

    var count = 0;
    for (final item in dueItems) {
      final anchor = item.anchorDay ?? item.nextDueDate.day;
      try {
        count += await transaction(() async {
          var next = item.nextDueDate;
          var made = 0;
          while (!next.isAfter(reference) && made < maxCatchUpPerSchedule) {
            await createTransaction(TransactionsCompanion(
              id: Value('rec_tx_${const Uuid().v4()}'),
              walletId: Value(item.walletId),
              toWalletId: Value(item.toWalletId),
              categoryId: Value(item.categoryId),
              amount: Value(item.amount),
              type: Value(item.type),
              note: Value('${item.name} (Otomatis)'),
              transactionDate: Value(next),
              createdAt: Value(reference),
            ));
            next = nextOccurrence(next, item.frequency, anchor);
            made++;
          }
          await (update(recurringTransactions)..where((t) => t.id.equals(item.id))).write(
            RecurringTransactionsCompanion(
              nextDueDate: Value(next),
              lastGeneratedDate: Value(reference),
              anchorDay: Value(anchor),
            ),
          );
          return made;
        });
      } on DataValidationException {
        await toggleRecurringActive(item.id, false);
      } on SqliteException {
        await toggleRecurringActive(item.id, false);
      }
    }
    return count;
  }

  // --- SEEDING & ONBOARDING HELPER (FR-01 & v2.0) ---

  Future<void> seedInitialData({
    required String walletName,
    required int initialBalance,
    required String walletIcon,
    required String walletColorHex,
    String walletType = 'E_WALLET',
    String institutionCode = 'CUSTOM',
    int? targetAmount,
  }) {
    return transaction(() async {
      // 1. Insert 10 Default Categories
      for (final cat in SeedData.defaultCategories) {
        await into(categories).insert(
          CategoriesCompanion(
            id: Value(cat.id),
            name: Value(cat.name),
            type: Value(cat.type),
            iconName: Value(cat.iconName),
            colorHex: Value(cat.colorHex),
            monthlyBudget: Value(cat.monthlyBudget),
            isDeleted: const Value(false),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }

      // 2. Insert Primary Wallet.
      // Jika dompet utama sudah ada (mis. onboarding diulang setelah preferensi terhapus),
      // perbarui tampilannya saja. Saldo tidak direset agar tetap konsisten dengan riwayat
      // transaksi, dan baris tidak di-REPLACE karena itu melanggar foreign key.
      final existing = await getWalletById('primary_wallet');
      if (existing != null) {
        await (update(wallets)..where((t) => t.id.equals('primary_wallet'))).write(
          WalletsCompanion(
            name: Value(walletName),
            iconName: Value(walletIcon),
            colorHex: Value(walletColorHex),
            isArchived: const Value(false),
            walletType: Value(walletType),
            institutionCode: Value(institutionCode),
            targetAmount: Value(targetAmount),
          ),
        );
        return;
      }

      await into(wallets).insert(
        WalletsCompanion(
          id: const Value('primary_wallet'),
          name: Value(walletName),
          initialBalance: Value(initialBalance),
          currentBalance: Value(initialBalance),
          iconName: Value(walletIcon),
          colorHex: Value(walletColorHex),
          isArchived: const Value(false),
          createdAt: Value(DateTime.now()),
          walletType: Value(walletType),
          institutionCode: Value(institutionCode),
          targetAmount: Value(targetAmount),
        ),
      );
    });
  }

  // --- BACKUP & RESTORE ATOMIC TRANSACTIONS (FR-07 & v2.0) ---

  Future<Map<String, dynamic>> exportDatabaseJson() async {
    final allWallets = await select(wallets).get();
    final allCategories = await select(categories).get();
    final allTransactions = await select(transactions).get();
    final allRecurring = await select(recurringTransactions).get();

    return {
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'appName': 'HITUNG',
      'wallets': allWallets
          .map((w) => {
                'id': w.id,
                'name': w.name,
                'initialBalance': w.initialBalance,
                'currentBalance': w.currentBalance,
                'iconName': w.iconName,
                'colorHex': w.colorHex,
                'isArchived': w.isArchived,
                'createdAt': w.createdAt.toIso8601String(),
                'walletType': w.walletType,
                'institutionCode': w.institutionCode,
                'targetAmount': w.targetAmount,
              })
          .toList(),
      'categories': allCategories
          .map((c) => {
                'id': c.id,
                'name': c.name,
                'type': c.type,
                'iconName': c.iconName,
                'colorHex': c.colorHex,
                'monthlyBudget': c.monthlyBudget,
                'isDeleted': c.isDeleted,
              })
          .toList(),
      'transactions': allTransactions
          .map((t) => {
                'id': t.id,
                'walletId': t.walletId,
                'toWalletId': t.toWalletId,
                'categoryId': t.categoryId,
                'amount': t.amount,
                'type': t.type,
                'note': t.note,
                'transactionDate': t.transactionDate.toIso8601String(),
                'createdAt': t.createdAt.toIso8601String(),
                'receiptPath': t.receiptPath,
              })
          .toList(),
      'recurringTransactions': allRecurring
          .map((r) => {
                'id': r.id,
                'name': r.name,
                'amount': r.amount,
                'type': r.type,
                'walletId': r.walletId,
                'toWalletId': r.toWalletId,
                'categoryId': r.categoryId,
                'frequency': r.frequency,
                'nextDueDate': r.nextDueDate.toIso8601String(),
                'lastGeneratedDate': r.lastGeneratedDate?.toIso8601String(),
                'isActive': r.isActive,
                'createdAt': r.createdAt.toIso8601String(),
                'anchorDay': r.anchorDay,
              })
          .toList(),
    };
  }

  /// Memvalidasi seluruh isi cadangan lebih dulu, baru mengganti data secara atomik.
  /// Jika ada yang tidak valid, [DataValidationException] dilempar dan data lama tetap utuh.
  /// Saldo dompet dihitung ulang dari saldo awal + riwayat transaksi, jadi file yang
  /// saldonya tidak cocok dengan transaksinya tidak bisa merusak konsistensi data.
  Future<void> atomicRestoreDatabaseJson(Map<String, dynamic> data) async {
    final parsed = BackupParser.parse(data);

    await transaction(() async {
      // Jadwal berulang merujuk dompet & kategori, jadi harus dihapus lebih dulu.
      await delete(recurringTransactions).go();
      await delete(transactions).go();
      await delete(categories).go();
      await delete(wallets).go();

      await batch((b) {
        b.insertAll(wallets, parsed.wallets);
        b.insertAll(categories, parsed.categories);
        b.insertAll(transactions, parsed.transactions);
        b.insertAll(recurringTransactions, parsed.recurring);
      });
    });
  }
}

/// Hasil parsing file cadangan yang sudah lolos validasi.
class ParsedBackup {
  final List<WalletsCompanion> wallets;
  final List<CategoriesCompanion> categories;
  final List<TransactionsCompanion> transactions;
  final List<RecurringTransactionsCompanion> recurring;

  const ParsedBackup(this.wallets, this.categories, this.transactions, [this.recurring = const []]);
}

/// Mengubah JSON cadangan menjadi baris database yang valid.
class BackupParser {
  static ParsedBackup parse(Map<String, dynamic> data) {
    final rawWallets = _list(data, 'wallets');
    final rawCategories = _list(data, 'categories');
    final rawTransactions = _list(data, 'transactions');

    // --- Dompet ---
    final walletInitial = <String, int>{};
    final walletRows = <String, Map<String, dynamic>>{};
    for (var i = 0; i < rawWallets.length; i++) {
      final w = _map(rawWallets[i], 'dompet #${i + 1}');
      final ctx = 'dompet #${i + 1}';
      final id = _requiredString(w, 'id', ctx);
      if (walletRows.containsKey(id)) throw DataValidationException('ID dompet "$id" muncul lebih dari sekali.');
      _name(w, ctx);
      walletInitial[id] = _int(w, 'initialBalance', ctx);
      walletRows[id] = w;
    }
    final hasActiveWallet = walletRows.values.any((w) => w['isArchived'] != true);
    if (!hasActiveWallet) {
      throw const DataValidationException('File cadangan tidak berisi dompet aktif.');
    }

    // --- Kategori ---
    final categoryIds = <String>{};
    final categoryCompanions = <CategoriesCompanion>[];
    for (var i = 0; i < rawCategories.length; i++) {
      final ctx = 'kategori #${i + 1}';
      final c = _map(rawCategories[i], ctx);
      final id = _requiredString(c, 'id', ctx);
      if (!categoryIds.add(id)) throw DataValidationException('ID kategori "$id" muncul lebih dari sekali.');
      final type = _requiredString(c, 'type', ctx);
      if (!DbEnums.categoryTypes.contains(type)) {
        throw DataValidationException('Tipe $ctx ("$type") tidak valid.');
      }
      final budget = _optionalInt(c, 'monthlyBudget', ctx);
      categoryCompanions.add(CategoriesCompanion(
        id: Value(id),
        name: Value(_name(c, ctx)),
        type: Value(type),
        iconName: Value(_string(c, 'iconName', ctx) ?? 'more-horizontal'),
        colorHex: Value(_color(c)),
        monthlyBudget: Value(budget != null && budget > 0 ? budget : null),
        isDeleted: Value(_bool(c, 'isDeleted', ctx)),
      ));
    }

    // --- Transaksi ---
    final balanceDelta = {for (final id in walletRows.keys) id: 0};
    final transactionIds = <String>{};
    final transactionCompanions = <TransactionsCompanion>[];
    for (var i = 0; i < rawTransactions.length; i++) {
      final ctx = 'transaksi #${i + 1}';
      final t = _map(rawTransactions[i], ctx);
      final id = _requiredString(t, 'id', ctx);
      if (!transactionIds.add(id)) throw DataValidationException('ID transaksi "$id" muncul lebih dari sekali.');

      final type = _requiredString(t, 'type', ctx);
      if (!DbEnums.transactionTypes.contains(type)) {
        throw DataValidationException('Tipe $ctx ("$type") tidak valid.');
      }
      final amount = _int(t, 'amount', ctx);
      if (amount <= 0) throw DataValidationException('Nominal $ctx harus lebih dari 0.');

      final walletId = _requiredString(t, 'walletId', ctx);
      if (!walletRows.containsKey(walletId)) {
        throw DataValidationException('$ctx merujuk dompet yang tidak ada ("$walletId").');
      }

      String? toWalletId;
      String? categoryId;
      if (type == 'TRANSFER') {
        toWalletId = _string(t, 'toWalletId', ctx);
        if (toWalletId == null || !walletRows.containsKey(toWalletId)) {
          throw DataValidationException('$ctx (transfer) merujuk dompet tujuan yang tidak ada.');
        }
        if (toWalletId == walletId) {
          throw DataValidationException('$ctx (transfer) memiliki dompet asal dan tujuan yang sama.');
        }
        balanceDelta[walletId] = balanceDelta[walletId]! - amount;
        balanceDelta[toWalletId] = balanceDelta[toWalletId]! + amount;
      } else {
        categoryId = _string(t, 'categoryId', ctx);
        if (categoryId != null && !categoryIds.contains(categoryId)) {
          throw DataValidationException('$ctx merujuk kategori yang tidak ada ("$categoryId").');
        }
        balanceDelta[walletId] = balanceDelta[walletId]! + (type == 'INCOME' ? amount : -amount);
      }

      transactionCompanions.add(TransactionsCompanion(
        id: Value(id),
        walletId: Value(walletId),
        toWalletId: Value(toWalletId),
        categoryId: Value(categoryId),
        amount: Value(amount),
        type: Value(type),
        note: Value(_string(t, 'note', ctx)),
        transactionDate: Value(_date(t, 'transactionDate', ctx)),
        createdAt: Value(_date(t, 'createdAt', ctx)),
        receiptPath: Value(_string(t, 'receiptPath', ctx)),
      ));
    }

    final walletCompanions = <WalletsCompanion>[];
    walletRows.forEach((id, w) {
      final ctx = 'dompet "$id"';
      final walletType = _string(w, 'walletType', ctx);
      final target = _optionalInt(w, 'targetAmount', ctx);
      final initial = walletInitial[id]!;
      walletCompanions.add(WalletsCompanion(
        id: Value(id),
        name: Value(_name(w, ctx)),
        initialBalance: Value(initial),
        currentBalance: Value(initial + balanceDelta[id]!),
        iconName: Value(_string(w, 'iconName', ctx) ?? 'wallet'),
        colorHex: Value(_color(w)),
        isArchived: Value(_bool(w, 'isArchived', ctx)),
        createdAt: Value(_date(w, 'createdAt', ctx)),
        walletType: Value(DbEnums.walletTypes.contains(walletType) ? walletType! : 'E_WALLET'),
        institutionCode: Value(_string(w, 'institutionCode', ctx) ?? 'CUSTOM'),
        targetAmount: Value(target != null && target > 0 ? target : null),
      ));
    });

    // --- Transaksi berulang (opsional; cadangan lama belum memilikinya) ---
    final recurringIds = <String>{};
    final recurringCompanions = <RecurringTransactionsCompanion>[];
    final rawRecurring = _list(data, 'recurringTransactions');
    for (var i = 0; i < rawRecurring.length; i++) {
      final ctx = 'jadwal berulang #${i + 1}';
      final r = _map(rawRecurring[i], ctx);
      final id = _requiredString(r, 'id', ctx);
      if (!recurringIds.add(id)) throw DataValidationException('ID jadwal "$id" muncul lebih dari sekali.');
      final name = _requiredString(r, 'name', ctx).trim();
      if (name.length > 100) throw DataValidationException('Nama $ctx melebihi 100 karakter.');
      final type = _requiredString(r, 'type', ctx);
      if (!DbEnums.transactionTypes.contains(type)) throw DataValidationException('Tipe $ctx tidak valid.');
      final frequency = _requiredString(r, 'frequency', ctx);
      if (!DbEnums.recurringFrequencies.contains(frequency)) {
        throw DataValidationException('Frekuensi $ctx tidak valid.');
      }
      final amount = _int(r, 'amount', ctx);
      if (amount <= 0) throw DataValidationException('Nominal $ctx harus lebih dari 0.');
      final walletId = _requiredString(r, 'walletId', ctx);
      if (!walletRows.containsKey(walletId)) throw DataValidationException('$ctx merujuk dompet yang tidak ada.');
      final toWalletId = _string(r, 'toWalletId', ctx);
      if (type == 'TRANSFER' && (toWalletId == null || !walletRows.containsKey(toWalletId) || toWalletId == walletId)) {
        throw DataValidationException('$ctx (transfer) memiliki dompet tujuan yang tidak valid.');
      }
      final categoryId = _string(r, 'categoryId', ctx);
      if (categoryId != null && !categoryIds.contains(categoryId)) {
        throw DataValidationException('$ctx merujuk kategori yang tidak ada.');
      }
      final anchor = _optionalInt(r, 'anchorDay', ctx);
      final lastGenerated = _string(r, 'lastGeneratedDate', ctx);
      recurringCompanions.add(RecurringTransactionsCompanion(
        id: Value(id),
        name: Value(name),
        amount: Value(amount),
        type: Value(type),
        walletId: Value(walletId),
        toWalletId: Value(type == 'TRANSFER' ? toWalletId : null),
        categoryId: Value(type == 'TRANSFER' ? null : categoryId),
        frequency: Value(frequency),
        nextDueDate: Value(_date(r, 'nextDueDate', ctx)),
        lastGeneratedDate: Value(lastGenerated == null ? null : _date(r, 'lastGeneratedDate', ctx)),
        isActive: Value(r['isActive'] == null ? true : _bool(r, 'isActive', ctx)),
        createdAt: Value(_date(r, 'createdAt', ctx)),
        anchorDay: Value(anchor != null && anchor >= 1 && anchor <= 31 ? anchor : null),
      ));
    }

    return ParsedBackup(walletCompanions, categoryCompanions, transactionCompanions, recurringCompanions);
  }

  // --- Helper pembaca field ---

  static List<dynamic> _list(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return const [];
    if (value is! List) throw DataValidationException('Bagian "$key" pada file cadangan tidak valid.');
    return value;
  }

  static Map<String, dynamic> _map(dynamic raw, String ctx) {
    if (raw is Map<String, dynamic>) return raw;
    throw DataValidationException('Data $ctx tidak valid.');
  }

  static String? _string(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v == null) return null;
    if (v is String) return v;
    throw DataValidationException('Field "$key" pada $ctx harus berupa teks.');
  }

  static String _requiredString(Map<String, dynamic> m, String key, String ctx) {
    final v = _string(m, key, ctx);
    if (v == null || v.trim().isEmpty) throw DataValidationException('Field "$key" pada $ctx wajib diisi.');
    return v;
  }

  static String _name(Map<String, dynamic> m, String ctx) {
    final name = _requiredString(m, 'name', ctx).trim();
    if (name.length > DbEnums.nameMaxLength) {
      throw DataValidationException('Nama pada $ctx melebihi ${DbEnums.nameMaxLength} karakter.');
    }
    return name;
  }

  static int? _optionalInt(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v == null) return null;
    if (v is int) return v;
    // Toleransi untuk angka bulat yang ditulis sebagai 1000.0
    if (v is double && v == v.truncateToDouble() && v.isFinite) return v.toInt();
    throw DataValidationException('Field "$key" pada $ctx harus berupa bilangan bulat.');
  }

  static int _int(Map<String, dynamic> m, String key, String ctx) {
    final v = _optionalInt(m, key, ctx);
    if (v == null) throw DataValidationException('Field "$key" pada $ctx wajib diisi.');
    return v;
  }

  static bool _bool(Map<String, dynamic> m, String key, String ctx) {
    final v = m[key];
    if (v == null) return false;
    if (v is bool) return v;
    throw DataValidationException('Field "$key" pada $ctx harus berupa true/false.');
  }

  static DateTime _date(Map<String, dynamic> m, String key, String ctx) {
    final v = _requiredString(m, key, ctx);
    final parsed = DateTime.tryParse(v);
    if (parsed == null) throw DataValidationException('Tanggal "$key" pada $ctx tidak valid.');
    return parsed;
  }

  static String _color(Map<String, dynamic> m) {
    final v = m['colorHex'];
    return v is String && ColorUtils.isValidHex(v) ? v : '#64748B';
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'hitung_app.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
