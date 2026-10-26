import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  static const nameMaxLength = AppConstants.maxNameLength;
}

@DriftDatabase(tables: [Wallets, Categories, Transactions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 2;

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
      createdAt: Value(tx.createdAt),
    ));
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
      await delete(transactions).go();
      await delete(categories).go();
      await delete(wallets).go();

      await batch((b) {
        b.insertAll(wallets, parsed.wallets);
        b.insertAll(categories, parsed.categories);
        b.insertAll(transactions, parsed.transactions);
      });
    });
  }
}

/// Hasil parsing file cadangan yang sudah lolos validasi.
class ParsedBackup {
  final List<WalletsCompanion> wallets;
  final List<CategoriesCompanion> categories;
  final List<TransactionsCompanion> transactions;

  const ParsedBackup(this.wallets, this.categories, this.transactions);
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

    return ParsedBackup(walletCompanions, categoryCompanions, transactionCompanions);
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
