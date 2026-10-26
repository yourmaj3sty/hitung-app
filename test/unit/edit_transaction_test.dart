import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/core/providers/database_provider.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:hitung/features/quick_entry/providers/quick_entry_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedInitialData(
      walletName: 'Utama',
      initialBalance: 1000000,
      walletIcon: 'wallet',
      walletColorHex: '#10B981',
    );
    await db.insertWallet(WalletsCompanion.insert(
      id: 'w2',
      name: 'Bank',
      initialBalance: const Value(500000),
      currentBalance: const Value(500000),
      iconName: 'landmark',
      colorHex: '#3B82F6',
      createdAt: DateTime(2026, 1, 1),
    ));
  });
  tearDown(() => db.close());

  TransactionsCompanion tx({
    String wallet = 'primary_wallet',
    String? toWallet,
    String? category = 'cat_expense_food',
    int amount = 100000,
    String type = 'EXPENSE',
  }) =>
      TransactionsCompanion(
        id: const Value('t1'),
        walletId: Value(wallet),
        toWalletId: Value(toWallet),
        categoryId: Value(category),
        amount: Value(amount),
        type: Value(type),
        transactionDate: Value(DateTime(2026, 10, 1)),
        createdAt: Value(DateTime(2026, 10, 1, 8)),
      );

  Future<int> balance(String id) async => (await db.getWalletById(id))!.currentBalance;

  test('ubah nominal menyesuaikan saldo dan mempertahankan createdAt', () async {
    await db.createTransaction(tx());
    expect(await balance('primary_wallet'), 900000);

    await db.updateTransactionWithRebalance(tx(amount: 250000).copyWith(createdAt: Value(DateTime(2030))));
    expect(await balance('primary_wallet'), 750000);
    final saved = (await db.getTransactionById('t1'))!;
    expect(saved.amount, 250000);
    expect(saved.createdAt, DateTime(2026, 10, 1, 8));
  });

  test('pindah dompet mengembalikan saldo dompet lama', () async {
    await db.createTransaction(tx());
    await db.updateTransactionWithRebalance(tx(wallet: 'w2'));
    expect(await balance('primary_wallet'), 1000000);
    expect(await balance('w2'), 400000);
  });

  test('ubah pengeluaran menjadi transfer lalu menjadi pemasukan', () async {
    await db.createTransaction(tx());
    await db.updateTransactionWithRebalance(tx(type: 'TRANSFER', toWallet: 'w2', category: null));
    expect(await balance('primary_wallet'), 900000);
    expect(await balance('w2'), 600000);

    await db.updateTransactionWithRebalance(tx(type: 'INCOME', category: 'cat_income_salary'));
    expect(await balance('primary_wallet'), 1100000);
    expect(await balance('w2'), 500000);
    expect((await db.select(db.transactions).get()).length, 1);
  });

  test('edit tidak valid dibatalkan seluruhnya', () async {
    await db.createTransaction(tx());
    await expectLater(
      db.updateTransactionWithRebalance(tx(type: 'INCOME', category: 'cat_expense_food')),
      throwsA(isA<DataValidationException>()),
    );
    expect(await balance('primary_wallet'), 900000);
    expect((await db.getTransactionById('t1'))!.type, 'EXPENSE');
  });

  test('edit transaksi yang tidak ada ditolak', () async {
    await expectLater(db.updateTransactionWithRebalance(tx()), throwsA(isA<DataValidationException>()));
  });

  test('QuickEntry: loadForEdit lalu simpan memperbarui transaksi yang sama', () async {
    await db.createTransaction(tx());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);
    final sub = c.listen(quickEntryProvider, (_, __) {});
    addTearDown(sub.close);
    final n = c.read(quickEntryProvider.notifier);

    n.loadForEdit((await db.getTransactionById('t1'))!);
    final s = c.read(quickEntryProvider);
    expect(s.isEditing, isTrue);
    expect(s.amount, 100000);
    expect(s.selectedCategoryId, 'cat_expense_food');

    n.appendKey('0'); // 1.000.000
    expect(await n.saveTransaction(), isTrue);
    final all = await db.select(db.transactions).get();
    expect(all, hasLength(1));
    expect(all.single.amount, 1000000);
    expect(await balance('primary_wallet'), 0);
  });
}
