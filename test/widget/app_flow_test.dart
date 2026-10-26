import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hitung/core/constants/app_constants.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/core/providers/database_provider.dart';
import 'package:hitung/features/analytics/presentation/analytics_screen.dart';
import 'package:hitung/features/budgeting/presentation/budgeting_screen.dart';
import 'package:hitung/features/navigation/main_nav_screen.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:hitung/features/quick_entry/presentation/quick_entry_sheet.dart';
import 'package:hitung/features/quick_entry/presentation/widgets/numpad_widget.dart';
import 'package:hitung/features/quick_entry/providers/quick_entry_provider.dart';
import 'package:hitung/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uji alur end-to-end di level widget: menjalankan HitungApp sungguhan dengan
/// database in-memory dan font yang dibundel (tanpa akses internet).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('catat pemasukan, swipe-hapus, undo, lalu pindah tab', (tester) async {
    // Font harus termuat dari assets/google_fonts, bukan dari internet.
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final db = AppDatabase(NativeDatabase.memory());
    late SharedPreferences prefs;
    await tester.runAsync(() async {
      await db.seedInitialData(
        walletName: 'Dompet Utama',
        initialBalance: 100000,
        walletIcon: 'wallet',
        walletColorHex: '#10B981',
      );
      SharedPreferences.setMockInitialValues({AppConstants.prefIsOnboarded: true});
      prefs = await SharedPreferences.getInstance();
    });

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
      child: const HitungApp(),
    ));

    // Stream drift butuh event loop nyata; beri kesempatan lalu render ulang.
    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    // Lewati splash screen.
    for (var i = 0; i < 20 && find.byType(MainNavScreen).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await settle();
    expect(find.byType(MainNavScreen), findsOneWidget);

    // --- Buka Quick Entry lewat FAB dan ganti ke "Catat Masuk" ---
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuickEntrySheet), findsOneWidget);
    await settle();

    await tester.tap(find.text('Catat Masuk (+)'));
    await tester.pump(const Duration(milliseconds: 300));

    Finder key(String k) => find.descendant(of: find.byType(NumpadWidget), matching: find.text(k));
    await tester.tap(key('5'));
    await tester.pump();
    await tester.tap(key('000'));
    await tester.pump();

    final state = ProviderScope.containerOf(tester.element(find.byType(QuickEntrySheet))).read(quickEntryProvider);
    expect(state.type, 'INCOME');
    expect(state.selectedCategoryId, 'cat_income_salary');
    expect(state.canSave, isTrue);
    await tester.tap(find.text('Simpan Transaksi'));
    // Tunggu proses simpan di database lalu animasi sukses & sheet tertutup.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(QuickEntrySheet), findsNothing);

    late List<Transaction> saved;
    await tester.runAsync(() async => saved = await db.select(db.transactions).get());
    expect(saved, hasLength(1));
    expect(saved.single.type, 'INCOME');
    expect(saved.single.amount, 5000);
    expect(saved.single.categoryId, 'cat_income_salary', reason: 'Bug #1: kategori harus kategori pemasukan');

    // --- Transaksi muncul di Beranda, lalu swipe-hapus ---
    await settle();
    expect(find.text('Gaji Utama'), findsWidgets);
    final txRow = find.byWidgetPredicate((w) => w is Dismissible && w.key == ValueKey(saved.single.id));
    expect(txRow, findsOneWidget);
    await tester.drag(txRow, const Offset(-600, 0));
    // Animasi geser (200 ms) + resize (250 ms), lalu onDismissed dipanggil.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await settle();
    expect(tester.takeException(), isNull, reason: 'Tidak boleh ada error Dismissible');
    expect(txRow, findsNothing);

    late Wallet wallet;
    await tester.runAsync(() async => wallet = (await db.getWalletById('primary_wallet'))!);
    expect(wallet.currentBalance, 100000);

    // --- Undo ---
    // Tunggu animasi masuk SnackBar selesai sebelum mengetuk Undo.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Urungkan (Undo)'));
    for (var i = 0; i < 20 && txRow.evaluate().isEmpty; i++) {
      await settle();
    }
    expect(txRow, findsOneWidget);
    await tester.runAsync(() async =>
        wallet = (await db.getWalletById('primary_wallet').timeout(const Duration(seconds: 5)))!);
    expect(wallet.currentBalance, 105000);

    // --- Pindah tab: semua layar tetap hidup (IndexedStack) ---
    await tester.tap(find.text('Anggaran'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Analisis'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BudgetingScreen, skipOffstage: false), findsOneWidget);
    expect(find.byType(AnalyticsScreen, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Bersihkan: lepas widget tree sebelum menutup database.
    await tester.pumpWidget(const SizedBox());
    final closing = db.close(); // dimulai di zona test agar tidak deadlock dengan kunci drift
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
    }
    await tester.runAsync(() => closing.timeout(const Duration(seconds: 5)));
    await tester.pump(const Duration(seconds: 5)); // habiskan timer SnackBar
  });
}
