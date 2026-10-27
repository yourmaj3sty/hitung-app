import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/features/backup_restore/services/encryption_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedInitialData(
      walletName: 'Dompet Utama',
      initialBalance: 1000000,
      walletIcon: 'wallet',
      walletColorHex: '#10B981',
      walletType: 'E_WALLET',
      institutionCode: 'GOPAY',
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Feature 1: Edit Transaksi Atomik', () {
    test('Mengedit nominal transaksi memperbarui saldo dompet secara presisi & atomik', () async {
      final cats = await db.getActiveCategories(type: 'EXPENSE');
      final catId = cats.first.id;

      // Buat pengeluaran Rp 200.000 (Saldo jadi 800.000)
      const txId = 'tx_atomic_test_1';
      await db.createTransaction(TransactionsCompanion(
        id: const Value(txId),
        walletId: const Value('primary_wallet'),
        categoryId: Value(catId),
        amount: const Value(200000),
        type: const Value('EXPENSE'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      var wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 800000);

      // Edit nominal menjadi Rp 350.000 (Saldo harusnya 1.000.000 - 350.000 = 650.000)
      await db.updateTransactionWithRebalance(TransactionsCompanion(
        id: const Value(txId),
        walletId: const Value('primary_wallet'),
        categoryId: Value(catId),
        amount: const Value(350000),
        type: const Value('EXPENSE'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 650000);

      final updatedTx = await db.getTransactionById(txId);
      expect(updatedTx?.amount, 350000);
    });
  });

  group('Feature 2: Kelola Kategori (Edit & Soft Delete)', () {
    test('updateCategory dan softDeleteCategory berfungsi dengan baik', () async {
      final cats = await db.getActiveCategories(type: 'EXPENSE');
      final targetCat = cats.first;

      // Edit nama dan anggaran
      await db.updateCategory(
        CategoriesCompanion(
          id: Value(targetCat.id),
          name: const Value('Makan Enak'),
          type: Value(targetCat.type),
          iconName: Value(targetCat.iconName),
          colorHex: Value(targetCat.colorHex),
          monthlyBudget: const Value(1500000),
        ),
      );

      var updated = await db.getCategoryById(targetCat.id);
      expect(updated?.name, 'Makan Enak');
      expect(updated?.monthlyBudget, 1500000);

      // Soft delete
      await db.softDeleteCategory(targetCat.id);
      final activeCats = await db.getActiveCategories(type: 'EXPENSE');
      expect(activeCats.any((c) => c.id == targetCat.id), isFalse);

      final deletedCat = await db.getCategoryById(targetCat.id);
      expect(deletedCat?.isDeleted, isTrue);
    });
  });

  group('Feature 3: Pulihkan Dompet Arsip & Koreksi Saldo', () {
    test('Mengarsipkan lalu memulihkan dompet', () async {
      await db.archiveWallet('primary_wallet');
      var active = await db.getActiveWallets();
      expect(active.isEmpty, isTrue);

      var archived = await db.getArchivedWallets();
      expect(archived.length, 1);
      expect(archived.first.id, 'primary_wallet');

      // Pulihkan dompet
      await db.unarchiveWallet('primary_wallet');
      active = await db.getActiveWallets();
      expect(active.length, 1);
      expect(active.first.isArchived, isFalse);
    });

    test('Koreksi saldo bank menghasilkan transaksi penyesuaian atomik', () async {
      // Saldo awal 1.000.000, bank aslinya 1.250.000 (Selisih +250.000)
      await db.adjustWalletBalance(
        walletId: 'primary_wallet',
        actualBalance: 1250000,
        note: 'Koreksi bunga bank',
      );

      final wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 1250000);

      final recentTxs = await db.select(db.transactions).get();
      final adjustTx = recentTxs.firstWhere((t) => t.note == 'Koreksi bunga bank');
      expect(adjustTx.type, 'INCOME');
      expect(adjustTx.amount, 250000);
    });
  });

  group('Feature 4: Cari dan Filter Transaksi', () {
    test('watchFilteredTransactions memfilter berdasarkan kata kunci dan tipe', () async {
      final cats = await db.getActiveCategories(type: 'EXPENSE');
      final now = DateTime.now();

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_search_1'),
        walletId: const Value('primary_wallet'),
        categoryId: Value(cats.first.id),
        amount: const Value(75000),
        type: const Value('EXPENSE'),
        note: const Value('Kopi Susu Senja'),
        transactionDate: Value(now),
        createdAt: Value(now),
      ));

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_search_2'),
        walletId: const Value('primary_wallet'),
        amount: const Value(500000),
        type: const Value('INCOME'),
        note: const Value('Bonus Kinerja'),
        transactionDate: Value(now),
        createdAt: Value(now),
      ));

      final results = await db.watchFilteredTransactions(queryText: 'Kopi').first;
      expect(results.length, 1);
      expect(results.first.transaction.note, 'Kopi Susu Senja');

      final incomeResults = await db.watchFilteredTransactions(type: 'INCOME').first;
      expect(incomeResults.length, 1);
      expect(incomeResults.first.transaction.amount, 500000);
    });
  });

  group('Feature 5: Enkripsi & Backup dengan Password', () {
    test('EncryptionService berhasil mengenkripsi dan mendekripsi payload', () {
      const originalPayload = '{"appName":"hitung.","wallets":[{"name":"BCA","balance":5000000}]}';
      const password = 'PasswordGenZ#123';

      final encrypted = EncryptionService.encrypt(originalPayload, password);
      expect(EncryptionService.isEncrypted(encrypted), isTrue);

      final decrypted = EncryptionService.decrypt(encrypted, password);
      expect(decrypted, originalPayload);

      // Password salah harus melempar FormatException
      expect(
        () => EncryptionService.decrypt(encrypted, 'WrongPassword'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Feature 6: Transaksi Berulang (Recurring)', () {
    test('Transaksi berulang jatuh tempo diproses otomatis ke tabel transaksi', () async {
      final pastDue = DateTime.now().subtract(const Duration(days: 2));

      await db.insertRecurringTransaction(
        RecurringTransactionsCompanion(
          id: const Value('rec_1'),
          name: const Value('Langganan Spotify'),
          amount: const Value(55000),
          type: const Value('EXPENSE'),
          walletId: const Value('primary_wallet'),
          frequency: const Value('MONTHLY'),
          nextDueDate: Value(pastDue),
          isActive: const Value(true),
          createdAt: Value(DateTime.now()),
        ),
      );

      final processed = await db.processDueRecurringTransactions();
      expect(processed, 1);

      // Verifikasi transaksi pengeluaran baru tercipta
      final txs = await db.select(db.transactions).get();
      expect(txs.any((t) => t.note?.contains('Langganan Spotify') ?? false), isTrue);

      // Verifikasi tanggal jatuh tempo berikutnya diperbarui ke bulan depan
      final recurringList = await db.getActiveRecurringTransactions();
      expect(recurringList.first.nextDueDate.isAfter(DateTime.now()), isTrue);
    });
  });

  group('Feature 7: Hitung Pengeluaran Bulanan untuk Peringatan Anggaran', () {
    test('getMonthlyExpenseForCategory dan getMonthlyTotalExpense menghitung total secara akurat', () async {
      final cats = await db.getActiveCategories(type: 'EXPENSE');
      final catId = cats.first.id;
      final now = DateTime.now();

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_budget_1'),
        walletId: const Value('primary_wallet'),
        categoryId: Value(catId),
        amount: const Value(800000),
        type: const Value('EXPENSE'),
        transactionDate: Value(now),
        createdAt: Value(now),
      ));

      final catSpent = await db.getMonthlyExpenseForCategory(catId, now);
      expect(catSpent, 800000);

      final totalSpent = await db.getMonthlyTotalExpense(now);
      expect(totalSpent, 800000);
    });
  });

  group('Feature 10: Lampiran Foto Struk', () {
    test('Transaksi menyimpan dan membaca kembali receiptPath lokal', () async {
      final now = DateTime.now();
      const receiptPath = '/app/documents/receipts/struk_belanja_01.jpg';

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_receipt_1'),
        walletId: const Value('primary_wallet'),
        amount: const Value(45000),
        type: const Value('EXPENSE'),
        receiptPath: const Value(receiptPath),
        transactionDate: Value(now),
        createdAt: Value(now),
      ));

      final tx = await db.getTransactionById('tx_receipt_1');
      expect(tx?.receiptPath, receiptPath);
    });
  });
}
