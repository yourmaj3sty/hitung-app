import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/core/providers/database_provider.dart';
import 'package:hitung/core/utils/color_utils.dart';
import 'package:hitung/core/utils/rupiah_input_formatter.dart';
import 'package:hitung/features/analytics/providers/analytics_provider.dart';
import 'package:hitung/features/backup_restore/services/export_file_utils.dart';
import 'package:hitung/features/backup_restore/services/json_backup_service.dart';
import 'package:hitung/features/budgeting/providers/budgeting_provider.dart';
import 'package:hitung/features/dashboard/providers/dashboard_provider.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:hitung/features/quick_entry/providers/quick_entry_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test regresi untuk bug yang ditemukan saat audit.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  Future<void> seed({int balance = 1000000}) => db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: balance,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );

  Future<void> addWallet(String id, {String type = 'BANK', int balance = 0}) => db.insertWallet(
        WalletsCompanion.insert(
          id: id,
          name: 'Dompet $id',
          initialBalance: Value(balance),
          currentBalance: Value(balance),
          iconName: 'wallet',
          colorHex: '#000000',
          createdAt: DateTime(2026, 1, 1),
          walletType: Value(type),
        ),
      );

  TransactionsCompanion tx(
    String id, {
    String wallet = 'primary_wallet',
    String? toWallet,
    String? category,
    int amount = 10000,
    String type = 'EXPENSE',
    DateTime? date,
  }) =>
      TransactionsCompanion(
        id: Value(id),
        walletId: Value(wallet),
        toWalletId: Value(toWallet),
        categoryId: Value(category),
        amount: Value(amount),
        type: Value(type),
        transactionDate: Value(date ?? DateTime.now()),
        createdAt: Value(DateTime.now()),
      );

  Future<ProviderContainer> makeContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('Bug #1 – Quick Entry: kategori mengikuti tipe transaksi', () {
    test('ganti EXPENSE -> INCOME memilih kategori pemasukan dan tersimpan benar', () async {
      await seed();
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      final n = c.read(quickEntryProvider.notifier);

      final all = await db.getActiveCategories();
      n.initDefaults(wallets: await db.getActiveWallets(), categories: all);
      expect(c.read(quickEntryProvider).selectedCategoryId, 'cat_expense_food');

      n.setType('INCOME', all);
      expect(c.read(quickEntryProvider).selectedCategoryId, 'cat_income_salary');

      n.appendKey('5');
      expect(await n.saveTransaction(), isTrue);
      final saved = (await db.select(db.transactions).get()).single;
      expect(saved.type, 'INCOME');
      expect(saved.categoryId, 'cat_income_salary');
    });

    test('initialType dari bento bar langsung memilih kategori yang cocok', () async {
      await seed();
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      c.read(quickEntryProvider.notifier).initDefaults(
            wallets: await db.getActiveWallets(),
            categories: await db.getActiveCategories(),
            initialType: 'INCOME',
          );
      final s = c.read(quickEntryProvider);
      expect(s.type, 'INCOME');
      expect(s.selectedCategoryId, 'cat_income_salary');
    });

    test('tipe tanpa kategori mengosongkan pilihan sehingga tidak bisa disimpan', () async {
      await seed();
      await db.softDeleteCategory('cat_income_salary');
      await db.softDeleteCategory('cat_income_bonus');
      await db.softDeleteCategory('cat_income_investment');
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      final n = c.read(quickEntryProvider.notifier);
      final all = await db.getActiveCategories();
      n.initDefaults(wallets: await db.getActiveWallets(), categories: all);
      n.setType('INCOME', all);
      n.appendKey('5');
      final s = c.read(quickEntryProvider);
      expect(s.selectedCategoryId, isNull);
      expect(s.canSave, isFalse);
    });

    test('copyWith bisa mengosongkan field nullable, dan tidak mengubahnya bila tidak diisi', () {
      final s = QuickEntryState(selectedWalletId: 'a', selectedToWalletId: 'b', selectedCategoryId: 'c');
      final cleared = s.copyWith(selectedToWalletId: null, selectedCategoryId: null);
      expect(cleared.selectedWalletId, 'a');
      expect(cleared.selectedToWalletId, isNull);
      expect(cleared.selectedCategoryId, isNull);
      expect(s.copyWith(note: 'x').selectedToWalletId, 'b');
    });

    test('memilih dompet asal yang sama dengan tujuan akan menukar keduanya', () async {
      await seed();
      await addWallet('w2');
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      final n = c.read(quickEntryProvider.notifier);
      n.initDefaults(wallets: await db.getActiveWallets(), categories: await db.getActiveCategories());
      n.setType('TRANSFER', const []);
      final from = c.read(quickEntryProvider).selectedWalletId!;
      final to = c.read(quickEntryProvider).selectedToWalletId!;
      expect(from, isNot(to));

      n.setWallet(to);
      expect(c.read(quickEntryProvider).selectedWalletId, to);
      expect(c.read(quickEntryProvider).selectedToWalletId, from);

      n.setToWallet(to);
      expect(c.read(quickEntryProvider).selectedWalletId, from);
      expect(c.read(quickEntryProvider).selectedToWalletId, to);
    });

    test('mode tabungan tanpa kantong tabungan tidak mengirim ke dompet biasa', () async {
      await seed();
      await addWallet('w2');
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      final n = c.read(quickEntryProvider.notifier);
      n.initSavingsMode(await db.getActiveWallets());
      n.appendKey('5');
      final s = c.read(quickEntryProvider);
      expect(s.type, 'TRANSFER');
      expect(s.selectedToWalletId, isNull);
      expect(s.canSave, isFalse);
    });

    test('mode tabungan memilih kantong tabungan sebagai tujuan', () async {
      await seed();
      await addWallet('savings', type: 'SAVINGS');
      final c = await makeContainer();
      final sub = c.listen(quickEntryProvider, (_, __) {});
      addTearDown(sub.close);
      c.read(quickEntryProvider.notifier).initSavingsMode(await db.getActiveWallets());
      final s = c.read(quickEntryProvider);
      expect(s.selectedWalletId, 'primary_wallet');
      expect(s.selectedToWalletId, 'savings');
    });
  });

  group('Validasi transaksi di database', () {
    test('menolak kategori yang tidak sesuai tipe transaksi', () async {
      await seed();
      expect(
        () => db.createTransaction(tx('t1', type: 'INCOME', category: 'cat_expense_food')),
        throwsA(isA<DataValidationException>()),
      );
      expect((await db.getWalletById('primary_wallet'))!.currentBalance, 1000000);
    });

    test('menolak nominal <= 0, tipe tidak dikenal, dan transfer ke dompet yang sama', () async {
      await seed();
      for (final bad in [
        tx('a', amount: 0),
        tx('b', amount: -5),
        tx('c', type: 'BOGUS'),
        tx('d', type: 'TRANSFER', toWallet: 'primary_wallet'),
        tx('e', type: 'TRANSFER'),
      ]) {
        await expectLater(db.createTransaction(bad), throwsA(isA<DataValidationException>()));
      }
      expect(await db.select(db.transactions).get(), isEmpty);
      expect((await db.getWalletById('primary_wallet'))!.currentBalance, 1000000);
    });

    test('menolak dompet yang tidak ada dan tidak meninggalkan baris setengah jadi', () async {
      await seed();
      await expectLater(db.createTransaction(tx('t1', wallet: 'ghost')), throwsA(anything));
      expect(await db.select(db.transactions).get(), isEmpty);
    });

    test('foreign key ditegakkan oleh SQLite', () async {
      await seed();
      await expectLater(
        db.into(db.transactions).insert(tx('t1', wallet: 'ghost')),
        throwsA(isA<SqliteException>()),
      );
    });

    test('transfer menyimpan kategori null walau UI mengirim kategori', () async {
      await seed();
      await addWallet('w2');
      await db.createTransaction(tx('t1', type: 'TRANSFER', toWallet: 'w2', category: 'cat_expense_food'));
      final saved = (await db.select(db.transactions).get()).single;
      expect(saved.categoryId, isNull);
      expect((await db.getWalletById('w2'))!.currentBalance, 10000);
    });

    test('onboarding ulang tidak gagal dan tidak mereset saldo bila sudah ada transaksi', () async {
      await seed(balance: 100000);
      await db.createTransaction(tx('t1', amount: 30000));
      await db.seedInitialData(
        walletName: 'Nama Baru',
        initialBalance: 999,
        walletIcon: 'wallet',
        walletColorHex: '#000000',
      );
      final w = (await db.getWalletById('primary_wallet'))!;
      expect(w.name, 'Nama Baru');
      expect(w.currentBalance, 70000);
    });
  });

  group('Bug #2 – Restore JSON tervalidasi', () {
    Map<String, dynamic> backup({
      List<Map<String, dynamic>>? wallets,
      List<Map<String, dynamic>>? categories,
      List<Map<String, dynamic>>? transactions,
    }) =>
        {
          'schemaVersion': 2,
          'wallets': wallets ??
              [
                {'id': 'w1', 'name': 'W1', 'initialBalance': 100000, 'currentBalance': 999999, 'iconName': 'wallet', 'colorHex': '#000000', 'createdAt': '2026-01-01T00:00:00'},
                {'id': 'w2', 'name': 'W2', 'initialBalance': 0, 'currentBalance': 0, 'iconName': 'wallet', 'colorHex': 'rusak', 'createdAt': '2026-01-01T00:00:00'},
              ],
          'categories': categories ??
              [
                {'id': 'c1', 'name': 'Makan', 'type': 'EXPENSE', 'iconName': 'utensils', 'colorHex': '#FF0000', 'isDeleted': true},
              ],
          'transactions': transactions ??
              [
                {'id': 't1', 'walletId': 'w1', 'categoryId': 'c1', 'amount': 25000, 'type': 'EXPENSE', 'transactionDate': '2026-01-02T00:00:00', 'createdAt': '2026-01-02T00:00:00'},
                {'id': 't2', 'walletId': 'w1', 'toWalletId': 'w2', 'amount': 10000, 'type': 'TRANSFER', 'transactionDate': '2026-01-03T00:00:00', 'createdAt': '2026-01-03T00:00:00'},
              ],
        };

    test('saldo dihitung ulang dari saldo awal + transaksi, warna rusak diganti', () async {
      await db.atomicRestoreDatabaseJson(backup());
      expect((await db.getWalletById('w1'))!.currentBalance, 100000 - 25000 - 10000);
      expect((await db.getWalletById('w2'))!.currentBalance, 10000);
      expect((await db.getWalletById('w2'))!.colorHex, '#64748B');
      expect((await db.getCategoryById('c1'))!.isDeleted, isTrue);
    });

    final invalidCases = <String, Map<String, dynamic> Function()>{
      'transaksi yatim': () => backup(transactions: [
            {'id': 't', 'walletId': 'GHOST', 'amount': 1, 'type': 'EXPENSE', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'nominal negatif': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'amount': -500, 'type': 'EXPENSE', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'tipe tidak dikenal': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'amount': 1, 'type': 'BOGUS', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'kategori tidak ada': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'categoryId': 'nope', 'amount': 1, 'type': 'EXPENSE', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'transfer ke dompet sama': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'toWalletId': 'w1', 'amount': 1, 'type': 'TRANSFER', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'nama terlalu panjang': () => backup(wallets: [
            {'id': 'w1', 'name': 'A' * 51, 'initialBalance': 0, 'iconName': 'wallet', 'colorHex': '#000000', 'createdAt': '2026-01-01T00:00:00'}
          ], transactions: []),
      'tanggal rusak': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'amount': 1, 'type': 'EXPENSE', 'transactionDate': 'kemarin', 'createdAt': '2026-01-01T00:00:00'}
          ]),
      'ID ganda': () => backup(transactions: [
            {'id': 't', 'walletId': 'w1', 'amount': 1, 'type': 'EXPENSE', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'},
            {'id': 't', 'walletId': 'w1', 'amount': 1, 'type': 'EXPENSE', 'transactionDate': '2026-01-01T00:00:00', 'createdAt': '2026-01-01T00:00:00'},
          ]),
      'tanpa dompet aktif': () => backup(wallets: [
            {'id': 'w1', 'name': 'W', 'initialBalance': 0, 'iconName': 'wallet', 'colorHex': '#000000', 'isArchived': true, 'createdAt': '2026-01-01T00:00:00'}
          ], transactions: []),
    };

    invalidCases.forEach((name, build) {
      test('menolak "$name" dan data lama tetap utuh', () async {
        await seed(balance: 123);
        await expectLater(db.atomicRestoreDatabaseJson(build()), throwsA(isA<DataValidationException>()));
        expect((await db.getWalletById('primary_wallet'))!.currentBalance, 123);
        expect((await db.getActiveCategories()).length, 10);
      });
    });

    test('JsonBackupService memberi pesan ramah untuk JSON rusak / versi baru / data tidak valid', () async {
      final service = JsonBackupService(db);
      expect(await service.restoreFromJsonString('{bukan json'), 'File bukan JSON yang valid.');
      expect(
        await service.restoreFromJsonString(jsonEncode({...backup(), 'schemaVersion': 99})),
        contains('tidak kompatibel'),
      );
      expect(
        await service.restoreFromJsonString(jsonEncode({...backup(), 'schemaVersion': '2'})),
        contains('tidak kompatibel'),
      );
      expect(
        await service.restoreFromJsonString(jsonEncode(invalidCases['transaksi yatim']!())),
        contains('Data lama tetap aman'),
      );
      expect(await service.restoreFromJsonString(jsonEncode(backup())), 'SUCCESS');
    });

    test('ekspor lalu restore menghasilkan data yang sama persis', () async {
      await seed();
      await addWallet('w2');
      await db.createTransaction(tx('t1', category: 'cat_expense_food', amount: 50000));
      await db.createTransaction(tx('t2', type: 'TRANSFER', toWallet: 'w2', amount: 20000));
      final exported = jsonDecode(jsonEncode(await db.exportDatabaseJson())) as Map<String, dynamic>;

      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await db2.atomicRestoreDatabaseJson(exported);
      expect((await db2.getWalletById('primary_wallet'))!.currentBalance, 1000000 - 50000 - 20000);
      expect((await db2.getWalletById('w2'))!.currentBalance, 20000);
      expect((await db2.select(db2.transactions).get()).length, 2);
    });
  });

  group('Provider anggaran, analitik, dan dashboard', () {
    test('anggaran tidak ikut berubah saat filter dompet Beranda dipilih', () async {
      await seed();
      await addWallet('w2', balance: 500000);
      await db.createTransaction(tx('t1', category: 'cat_expense_food', amount: 100000));
      await db.createTransaction(tx('t2', wallet: 'w2', category: 'cat_expense_food', amount: 50000));

      final c = await makeContainer();
      c.read(selectedWalletFilterProvider.notifier).state = 'w2';
      final sub = c.listen(monthTransactionsAllWalletsProvider, (_, __) {});
      final subCats = c.listen(activeCategoriesStreamProvider('EXPENSE'), (_, __) {});
      final subDash = c.listen(dashboardTransactionsProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(subCats.close);
      addTearDown(subDash.close);
      await c.read(monthTransactionsAllWalletsProvider.future);
      await c.read(activeCategoriesStreamProvider('EXPENSE').future);
      await c.read(dashboardTransactionsProvider.future);

      final food = c.read(categoryBudgetItemsProvider).firstWhere((i) => i.category.id == 'cat_expense_food');
      expect(food.spentAmount, 150000);
      expect(c.read(monthlySummaryAllWalletsProvider).totalExpense, 150000);
      expect(c.read(monthlySummaryProvider).totalExpense, 50000); // Beranda tetap terfilter
    });

    test('analitik menghitung kategori terhapus & tanpa kategori, persentase total 100', () async {
      await seed();
      await db.createTransaction(tx('t1', category: 'cat_expense_food', amount: 1));
      await db.createTransaction(tx('t2', category: 'cat_expense_transport', amount: 1));
      await db.createTransaction(tx('t3', amount: 1)); // tanpa kategori
      await db.softDeleteCategory('cat_expense_transport');

      final c = await makeContainer();
      final sub = c.listen(monthTransactionsAllWalletsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(monthTransactionsAllWalletsProvider.future);

      final items = c.read(categoryAnalyticsListProvider);
      expect(items.length, 3);
      expect(items.map((i) => i.category.id), contains('cat_expense_transport'));
      expect(items.map((i) => i.category.id), contains(uncategorizedExpenseCategory.id));
      expect(items.fold<int>(0, (s, i) => s + i.percentage), 100);
    });

    test('distributePercentages selalu berjumlah 100', () {
      expect(distributePercentages([1, 1, 1]).reduce((a, b) => a + b), 100);
      expect(distributePercentages([2, 1]), [67, 33]);
      expect(distributePercentages([0, 0]), [0, 0]);
      expect(distributePercentages([999999999999, 1]).reduce((a, b) => a + b), 100);
    });

    test('perbandingan bulanan ter-update otomatis saat transaksi ditambah', () async {
      await seed();
      final c = await makeContainer();
      final now = DateTime.now();
      c.read(selectedDateFilterProvider.notifier).state = DateTime(now.year, now.month, 1);
      await db.createTransaction(tx('prev', amount: 40000, date: DateTime(now.year, now.month - 1, 15)));

      final values = <MonthComparison>[];
      final sub = c.listen<AsyncValue<MonthComparison>>(monthComparisonProvider, (_, next) {
        if (next.hasValue) values.add(next.value!);
      }, fireImmediately: true);
      addTearDown(sub.close);
      await c.read(monthComparisonProvider.future);

      await db.createTransaction(tx('cur', amount: 60000, date: now));
      await pumpEventQueue();

      expect(values.last.previousMonthExpense, 40000);
      expect(values.last.currentMonthExpense, 60000);
      expect(values.last.percentageChange, 50);
    });

    test('batas bulan: hari terakhir 23:59:59 masuk, tanggal 1 bulan depan tidak', () async {
      await seed();
      await db.createTransaction(tx('last', amount: 1, date: DateTime(2026, 2, 28, 23, 59, 59)));
      await db.createTransaction(tx('next', amount: 2, date: DateTime(2026, 3, 1)));
      await db.createTransaction(tx('first', amount: 4, date: DateTime(2026, 2, 1)));

      final c = await makeContainer();
      c.read(selectedDateFilterProvider.notifier).state = DateTime(2026, 2, 1);
      final items = await c.read(dashboardTransactionsProvider.future);
      expect(items.map((i) => i.transaction.id).toSet(), {'last', 'first'});
    });

    test('dompet tujuan transfer terbaca lewat JOIN', () async {
      await seed();
      await addWallet('w2');
      await db.createTransaction(tx('t1', type: 'TRANSFER', toWallet: 'w2'));
      final c = await makeContainer();
      final items = await c.read(dashboardTransactionsProvider.future);
      expect(items.single.toWallet?.id, 'w2');
      expect(items.single.wallet.id, 'primary_wallet');
    });

    test('transaksi yang sedang dihapus langsung disembunyikan dari Beranda', () async {
      await seed();
      await db.createTransaction(tx('t1'));
      await db.createTransaction(tx('t2'));
      final c = await makeContainer();
      final sub = c.listen(dashboardTransactionsProvider, (_, __) {});
      addTearDown(sub.close);
      await c.read(dashboardTransactionsProvider.future);

      c.read(pendingDeletedTxIdsProvider.notifier).state = {'t1'};
      final visible = c.read(groupedDashboardTransactionsProvider).expand((g) => g.items);
      expect(visible.map((i) => i.transaction.id), ['t2']);
    });
  });

  group('Utilitas', () {
    test('ColorUtils tidak crash untuk warna rusak', () {
      expect(ColorUtils.fromHex('#10B981'), const Color(0xFF10B981));
      expect(ColorUtils.fromHex('10B981'), const Color(0xFF10B981));
      expect(ColorUtils.fromHex('#8010B981'), const Color(0x8010B981));
      for (final bad in ['', 'rusak', '#12', null, '#GGGGGG']) {
        expect(ColorUtils.fromHex(bad), ColorUtils.fallback);
      }
    });

    test('RupiahInputFormatter memformat, membatasi 12 digit, dan menjaga kursor', () {
      const f = RupiahInputFormatter();
      TextEditingValue type(String old, String text, int cursor) => f.formatEditUpdate(
            TextEditingValue(text: old),
            TextEditingValue(text: text, selection: TextSelection.collapsed(offset: cursor)),
          );

      expect(type('', '1500000', 7).text, '1.500.000');
      expect(type('', '1500000', 7).selection.baseOffset, 9);
      // Paste 20 digit ditolak, nilai lama dipertahankan.
      expect(type('1.000', '12345678901234567890', 20).text, '1.000');
      expect(type('', '999999999999', 12).text, '999.999.999.999');
      expect(type('1', '', 0).text, '');
      // Sisip angka di tengah: kursor tetap tepat setelah angka yang diketik.
      final mid = type('1.000', '15.000', 2); // mengetik "5" setelah "1"
      expect(mid.text, '15.000');
      expect(mid.selection.baseOffset, 2);
    });

    test('csvCell meng-escape kutip dan menetralkan rumus spreadsheet', () {
      expect(ExportFileUtils.csvCell('Makan "enak"'), '"Makan ""enak"""');
      expect(ExportFileUtils.csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
      expect(ExportFileUtils.csvCell('+62'), '"\'+62"');
      expect(ExportFileUtils.csvCell(null), '""');
      expect(ExportFileUtils.csvCell('biasa'), '"biasa"');
    });
  });
}
