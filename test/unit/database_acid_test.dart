import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory SQLite database for fast isolated unit testing
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('PRD Rule 4 & 5: Database ACID Transactions & Soft Delete Tests', () {
    test('Initial seeding creates 10 categories and primary wallet with v2 columns', () async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 1000000, // Rp 1.000.000
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
        walletType: 'E_WALLET',
        institutionCode: 'GOPAY',
      );

      final wallets = await db.getActiveWallets();
      expect(wallets.length, 1);
      expect(wallets.first.name, 'Dompet Utama');
      expect(wallets.first.currentBalance, 1000000);
      expect(wallets.first.walletType, 'E_WALLET');
      expect(wallets.first.institutionCode, 'GOPAY');
      expect(db.schemaVersion, 3);

      final expenseCats = await db.getActiveCategories(type: 'EXPENSE');
      final incomeCats = await db.getActiveCategories(type: 'INCOME');

      expect(expenseCats.length, 7);
      expect(incomeCats.length, 3);
      expect(expenseCats.length + incomeCats.length, 10);
    });

    test('ACID: Expense transaction atomically decreases wallet balance', () async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 500000,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_expense_1'),
        walletId: const Value('primary_wallet'),
        amount: const Value(150000), // Rp 150.000
        type: const Value('EXPENSE'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      final wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 350000); // 500.000 - 150.000
    });

    test('ACID: Income transaction atomically increases wallet balance', () async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 500000,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );

      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_income_1'),
        walletId: const Value('primary_wallet'),
        amount: const Value(300000), // Rp 300.000
        type: const Value('INCOME'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      final wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 800000); // 500.000 + 300.000
    });

    test('ACID: Transfer transaction updates both source and target wallets atomically', () async {
      await db.seedInitialData(
        walletName: 'BCA',
        initialBalance: 1000000,
        walletIcon: 'landmark',
        walletColorHex: '#10B981',
      );

      // Create target wallet
      await db.insertWallet(WalletsCompanion(
        id: const Value('wallet_gopay'),
        name: const Value('GoPay'),
        initialBalance: const Value(50000),
        currentBalance: const Value(50000),
        iconName: const Value('smartphone'),
        colorHex: const Value('#3B82F6'),
        isArchived: const Value(false),
        createdAt: Value(DateTime.now()),
        walletType: const Value('E_WALLET'),
        institutionCode: const Value('GOPAY'),
      ));

      // Transfer 200.000 from BCA to GoPay
      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_transfer_1'),
        walletId: const Value('primary_wallet'),
        toWalletId: const Value('wallet_gopay'),
        amount: const Value(200000),
        type: const Value('TRANSFER'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      final fromW = await db.getWalletById('primary_wallet');
      final toW = await db.getWalletById('wallet_gopay');

      expect(fromW?.currentBalance, 800000);  // 1.000.000 - 200.000
      expect(toW?.currentBalance, 250000);    // 50.000 + 200.000
    });

    test('ACID: Isi Tabungan - Transfer from Daily Wallet to Savings Pocket', () async {
      await db.seedInitialData(
        walletName: 'BCA Harian',
        initialBalance: 2000000,
        walletIcon: 'landmark',
        walletColorHex: '#0060AF',
        walletType: 'BANK',
        institutionCode: 'BCA',
      );

      // Create Kantong Tabungan
      await db.insertWallet(WalletsCompanion(
        id: const Value('savings_pocket_1'),
        name: const Value('Nonton Konser'),
        initialBalance: const Value(100000),
        currentBalance: const Value(100000),
        iconName: const Value('piggy-bank'),
        colorHex: const Value('#00AED6'),
        isArchived: const Value(false),
        createdAt: Value(DateTime.now()),
        walletType: const Value('SAVINGS'),
        institutionCode: const Value('JAGO'),
        targetAmount: const Value(1500000), // Target: 1.5 juta
      ));

      // Sisihkan 400.000 dari BCA ke Kantong Tabungan
      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_isi_tabungan_1'),
        walletId: const Value('primary_wallet'),
        toWalletId: const Value('savings_pocket_1'),
        amount: const Value(400000),
        type: const Value('TRANSFER'),
        note: const Value('Sisihkan gaji bulanan'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      final sourceWallet = await db.getWalletById('primary_wallet');
      final savingsPocket = await db.getWalletById('savings_pocket_1');

      expect(sourceWallet?.currentBalance, 1600000); // 2.000.000 - 400.000
      expect(savingsPocket?.currentBalance, 500000); // 100.000 + 400.000
      expect(savingsPocket?.targetAmount, 1500000);
      expect(savingsPocket?.walletType, 'SAVINGS');
      expect(savingsPocket?.institutionCode, 'JAGO');
    });

    test('ACID: Swipe-to-delete reverts wallet balance and Undo restores it', () async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 500000,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );

      // Create expense
      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_to_delete'),
        walletId: const Value('primary_wallet'),
        amount: const Value(100000),
        type: const Value('EXPENSE'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      var wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 400000);

      // Swipe delete with revert
      final deletedTx = await db.deleteTransactionWithRevert('tx_to_delete');
      expect(deletedTx, isNotNull);

      wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 500000); // Restored!

      // Undo action
      await db.restoreTransaction(deletedTx!);
      wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.currentBalance, 400000); // Re-applied!
    });

    test('Rule 5: Soft delete archives wallet and flags category without hard delete', () async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 500000,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );

      // Archive wallet
      await db.archiveWallet('primary_wallet');
      final activeWallets = await db.getActiveWallets();
      expect(activeWallets.isEmpty, true);

      final wallet = await db.getWalletById('primary_wallet');
      expect(wallet?.isArchived, true); // Still in database, just archived

      // Soft delete category
      await db.softDeleteCategory('cat_expense_food');
      final activeCats = await db.getActiveCategories();
      expect(activeCats.any((c) => c.id == 'cat_expense_food'), false);

      final cat = await db.getCategoryById('cat_expense_food');
      expect(cat?.isDeleted, true); // Soft-deleted
    });
  });
}
