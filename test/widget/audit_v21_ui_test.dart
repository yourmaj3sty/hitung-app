import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitung/core/constants/app_constants.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/core/providers/database_provider.dart';
import 'package:hitung/core/theme/app_theme.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:hitung/features/recurring/presentation/recurring_transactions_screen.dart';
import 'package:hitung/features/settings/presentation/biometric_lock_screen.dart';
import 'package:hitung/features/settings/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('form transaksi berulang: kategori mengikuti tipe, tahunan tersimpan', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      await db.seedInitialData(walletName: 'Utama', initialBalance: 0, walletIcon: 'wallet', walletColorHex: '#000000');
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const RecurringTransactionsScreen()),
    ));
    await settle(tester);

    await tester.tap(find.text('Tambah Transaksi Berulang'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.text('Makanan & Minuman'), findsOneWidget); // kategori pengeluaran default

    await tester.tap(find.text('Pemasukan'));
    await tester.pump();
    await settle(tester);
    expect(find.text('Gaji Utama'), findsOneWidget, reason: 'kategori harus berganti ke kategori pemasukan');
    expect(find.text('Makanan & Minuman'), findsNothing);

    await tester.enterText(find.widgetWithText(TextField, 'Nama Transaksi Berulang'), 'Gaji');
    await tester.enterText(find.widgetWithText(TextField, 'Nominal'), '5000000');
    await tester.tap(find.text('Bulanan (Setiap Bulan)'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tahunan (Setiap Tahun)').last);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('Simpan Transaksi Berulang'));
    await tester.tap(find.text('Simpan Transaksi Berulang'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));

    late List<RecurringTransaction> saved;
    await tester.runAsync(() async => saved = await db.select(db.recurringTransactions).get());
    expect(saved, hasLength(1));
    expect(saved.single.type, 'INCOME');
    expect(saved.single.categoryId, 'cat_income_salary');
    expect(saved.single.frequency, 'YEARLY');
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    final closing = db.close();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.runAsync(() => closing);
  });

  testWidgets('layar kunci khusus PIN langsung meminta PIN dan PIN benar membuka kunci', (tester) async {
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({AppConstants.prefPinEnabled: true});
      prefs = await SharedPreferences.getInstance();
    });
    final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(settingsControllerProvider.notifier).setAppPin('2468'));
    container.read(isAppLockedProvider.notifier).state = true;

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.lightTheme, home: const BiometricLockScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Masukkan PIN Aplikasi'), findsOneWidget);
    expect(find.text('Pindai Sidik Jari'), findsNothing, reason: 'biometrik tidak aktif');

    await tester.enterText(find.byType(TextField), '2468');
    await tester.tap(find.text('Buka'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(container.read(isAppLockedProvider), isFalse);
  });
}
