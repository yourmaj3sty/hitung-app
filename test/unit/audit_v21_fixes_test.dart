import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/constants/app_constants.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/core/services/budget_alert_checker.dart';
import 'package:hitung/core/services/notification_service.dart';
import 'package:hitung/features/analytics/services/pdf_report_service.dart';
import 'package:hitung/features/backup_restore/services/encryption_service.dart';
import 'package:hitung/features/backup_restore/services/json_backup_service.dart';
import 'package:hitung/features/onboarding/providers/onboarding_provider.dart';
import 'package:hitung/features/settings/providers/settings_provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;

/// Test regresi untuk temuan audit fitur v2.1.
class _NoDeviceLockAuth extends LocalAuthentication {
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      throw PlatformException(code: 'NotAvailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.seedInitialData(walletName: 'Utama', initialBalance: 1000000, walletIcon: 'wallet', walletColorHex: '#000000');
    await db.insertWallet(WalletsCompanion.insert(
      id: 'w2',
      name: 'Bank',
      iconName: 'landmark',
      colorHex: '#3B82F6',
      createdAt: DateTime(2026, 1, 1),
    ));
  });
  tearDown(() => db.close());

  RecurringTransactionsCompanion rec(
    String id, {
    String type = 'EXPENSE',
    String? category = 'cat_expense_food',
    String? toWallet,
    String frequency = 'MONTHLY',
    required DateTime due,
  }) =>
      RecurringTransactionsCompanion.insert(
        id: id,
        name: 'Jadwal $id',
        amount: 10000,
        type: type,
        walletId: 'primary_wallet',
        toWalletId: Value(toWallet),
        categoryId: Value(category),
        frequency: frequency,
        nextDueDate: due,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<List<Transaction>> allTx() => db.select(db.transactions).get();
  Future<RecurringTransaction> getRec(String id) =>
      (db.select(db.recurringTransactions)..where((t) => t.id.equals(id))).getSingle();

  group('Backup & restore transaksi berulang', () {
    test('jadwal ikut diekspor dan restore tidak lagi gagal foreign key', () async {
      await db.insertRecurringTransaction(rec('r1', due: DateTime(2026, 11, 1)));
      final exported = jsonDecode(jsonEncode(await db.exportDatabaseJson())) as Map<String, dynamic>;
      expect((exported['recurringTransactions'] as List), hasLength(1));

      await db.atomicRestoreDatabaseJson(exported); // sebelumnya: FOREIGN KEY constraint failed
      final r = await getRec('r1');
      expect(r.name, 'Jadwal r1');
      expect(r.anchorDay, 1);
    });

    test('cadangan lama tanpa jadwal tetap bisa dipulihkan dan menghapus jadwal yang ada', () async {
      await db.insertRecurringTransaction(rec('r1', due: DateTime(2026, 11, 1)));
      final exported = jsonDecode(jsonEncode(await db.exportDatabaseJson())) as Map<String, dynamic>;
      exported.remove('recurringTransactions');
      await db.atomicRestoreDatabaseJson(exported);
      expect(await db.select(db.recurringTransactions).get(), isEmpty);
    });

    test('jadwal yang merujuk dompet tidak ada ditolak, data lama utuh', () async {
      final exported = jsonDecode(jsonEncode(await db.exportDatabaseJson())) as Map<String, dynamic>;
      exported['recurringTransactions'] = [
        {
          'id': 'x', 'name': 'X', 'amount': 1, 'type': 'EXPENSE', 'walletId': 'GHOST', 'frequency': 'MONTHLY',
          'nextDueDate': '2026-11-01T00:00:00', 'createdAt': '2026-01-01T00:00:00',
        }
      ];
      await expectLater(db.atomicRestoreDatabaseJson(exported), throwsA(isA<DataValidationException>()));
      expect((await db.getWalletById('w2')), isNotNull);
    });
  });

  group('Pemrosesan transaksi berulang', () {
    test('jadwal tidak valid dinonaktifkan dan tidak memblokir jadwal lain', () async {
      final now = DateTime(2026, 10, 20, 12);
      await db.insertRecurringTransaction(rec('good', due: DateTime(2026, 10, 20)));
      // Simulasikan data rusak dari versi lama (kategori pengeluaran untuk pemasukan).
      await db.into(db.recurringTransactions).insert(rec('bad', type: 'INCOME', due: DateTime(2026, 10, 20)));

      final count = await db.processDueRecurringTransactions(now: now);
      expect(count, 1);
      expect((await allTx()).single.categoryId, 'cat_expense_food');
      expect((await getRec('bad')).isActive, isFalse);
      expect((await getRec('good')).nextDueDate, DateTime(2026, 11, 20));
    });

    test('semua kemunculan yang terlewat dibuat sekaligus', () async {
      await db.insertRecurringTransaction(rec('m', due: DateTime(2026, 7, 15)));
      final count = await db.processDueRecurringTransactions(now: DateTime(2026, 10, 20));
      expect(count, 4); // 15 Jul, Agu, Sep, Okt
      final dates = (await allTx()).map((t) => t.transactionDate.month).toList()..sort();
      expect(dates, [7, 8, 9, 10]);
      expect((await getRec('m')).nextDueDate, DateTime(2026, 11, 15));
      expect((await db.getWalletById('primary_wallet'))!.currentBalance, 1000000 - 40000);
    });

    test('jadwal tanggal 31 kembali ke 31 setelah Februari', () {
      var d = DateTime(2026, 1, 31);
      final seen = <String>[];
      for (var i = 0; i < 4; i++) {
        seen.add('${d.month}/${d.day}');
        d = AppDatabase.nextOccurrence(d, 'MONTHLY', 31);
      }
      expect(seen, ['1/31', '2/28', '3/31', '4/30']);
    });

    test('frekuensi tahunan benar-benar tahunan (termasuk 29 Februari)', () async {
      expect(AppDatabase.nextOccurrence(DateTime(2028, 2, 29), 'YEARLY', 29), DateTime(2029, 2, 28));
      expect(AppDatabase.nextOccurrence(DateTime(2031, 2, 28), 'YEARLY', 29), DateTime(2032, 2, 29));

      await db.insertRecurringTransaction(rec('y', frequency: 'YEARLY', due: DateTime(2026, 3, 1)));
      final count = await db.processDueRecurringTransactions(now: DateTime(2026, 10, 1));
      expect(count, 1);
      expect((await getRec('y')).nextDueDate, DateTime(2027, 3, 1));
    });

    test('menyimpan jadwal dengan kategori yang tidak cocok ditolak', () async {
      await expectLater(
        db.insertRecurringTransaction(rec('x', type: 'INCOME', due: DateTime(2026, 11, 1))),
        throwsA(isA<DataValidationException>()),
      );
      await expectLater(
        db.insertRecurringTransaction(rec('t', type: 'TRANSFER', category: null, toWallet: 'primary_wallet', due: DateTime(2026, 11, 1))),
        throwsA(isA<DataValidationException>()),
      );
    });
  });

  group('PIN & kunci aplikasi', () {
    Future<ProviderContainer> container(Map<String, Object> prefsValues, {LocalAuthentication? auth}) async {
      SharedPreferences.setMockInitialValues(prefsValues);
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (auth != null) localAuthProvider.overrideWithValue(auth),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('PIN disimpan sebagai hash, bukan teks biasa', () async {
      final c = await container({});
      await c.read(settingsControllerProvider.notifier).setAppPin('123456');
      final stored = c.read(sharedPreferencesProvider).getString(AppConstants.prefAppPin)!;
      expect(stored, isNot(contains('123456')));
      expect(stored, startsWith('v1\$'));
      expect((await c.read(settingsControllerProvider.notifier).verifyAppPin('123456')).success, isTrue);
    });

    test('5 kali salah mengunci input, PIN benar pun ditolak sampai waktunya habis', () async {
      final c = await container({});
      final ctl = c.read(settingsControllerProvider.notifier);
      await ctl.setAppPin('1234');
      final t0 = DateTime(2026, 10, 1, 10);
      PinCheckResult r = const PinCheckResult.wrong(0);
      for (var i = 0; i < 5; i++) {
        r = await ctl.verifyAppPin('0000', now: t0);
      }
      expect(r.isLocked, isTrue);
      expect(r.lockedFor, const Duration(seconds: 30));
      expect((await ctl.verifyAppPin('1234', now: t0.add(const Duration(seconds: 10)))).success, isFalse);
      expect((await ctl.verifyAppPin('1234', now: t0.add(const Duration(seconds: 31)))).success, isTrue);
    });

    test('PIN lama (teks biasa) tetap bisa dipakai lalu diubah menjadi hash', () async {
      final c = await container({AppConstants.prefAppPin: '4321', AppConstants.prefPinEnabled: true});
      expect((await c.read(settingsControllerProvider.notifier).verifyAppPin('4321')).success, isTrue);
      expect(c.read(sharedPreferencesProvider).getString(AppConstants.prefAppPin), startsWith('v1\$'));
    });

    test('kunci layar perangkat tidak aktif + PIN aktif -> aplikasi TETAP terkunci', () async {
      final c = await container(
        {AppConstants.prefPinEnabled: true, AppConstants.prefBiometricEnabled: true},
        auth: _NoDeviceLockAuth(),
      );
      c.read(isAppLockedProvider.notifier).state = true;
      final r = await c.read(settingsControllerProvider.notifier).unlockApp();
      expect(r, UnlockResult.unavailable);
      expect(c.read(isAppLockedProvider), isTrue);
      expect(c.read(isBiometricEnabledProvider), isFalse);
    });

    test('tanpa PIN, kunci layar tidak aktif tetap membuka aplikasi (tidak terkunci selamanya)', () async {
      final c = await container({AppConstants.prefBiometricEnabled: true}, auth: _NoDeviceLockAuth());
      c.read(isAppLockedProvider.notifier).state = true;
      await c.read(settingsControllerProvider.notifier).unlockApp();
      expect(c.read(isAppLockedProvider), isFalse);
    });
  });

  group('Zona waktu notifikasi', () {
    setUpAll(tzdata.initializeTimeZones);

    test('offset Indonesia dipetakan ke WIB/WITA/WIT, bukan UTC', () {
      expect(NotificationService.resolveLocalLocation(offset: const Duration(hours: 7)).name, 'Asia/Jakarta');
      expect(NotificationService.resolveLocalLocation(offset: const Duration(hours: 8)).name, 'Asia/Makassar');
      expect(NotificationService.resolveLocalLocation(offset: const Duration(hours: 9)).name, 'Asia/Jayapura');
    });

    test('offset lain memilih lokasi dengan offset yang sama', () {
      final loc = NotificationService.resolveLocalLocation(
        offset: const Duration(hours: 1),
        abbreviation: 'CET',
        now: DateTime.utc(2026, 1, 15),
      );
      expect(loc.timeZone(DateTime.utc(2026, 1, 15).millisecondsSinceEpoch).offset, const Duration(hours: 1));
    });
  });

  group('Enkripsi cadangan V2', () {
    test('round-trip, kata sandi berspasi dipakai apa adanya', () {
      final enc = EncryptionService.encrypt('{"a":1}', ' rahasia ', iterations: 1000);
      expect(EncryptionService.isEncrypted(enc), isTrue);
      expect(EncryptionService.decrypt(enc, ' rahasia '), '{"a":1}');
      expect(() => EncryptionService.decrypt(enc, 'rahasia'), throwsFormatException);
    });

    test('file yang diubah ditolak oleh MAC', () {
      final env = jsonDecode(EncryptionService.encrypt('{"saldo":100}', 'sandi123', iterations: 1000)) as Map<String, dynamic>;
      final bytes = base64Decode(env['ciphertext'] as String);
      bytes[0] ^= 0x01;
      env['ciphertext'] = base64Encode(bytes);
      expect(() => EncryptionService.decrypt(jsonEncode(env), 'sandi123'), throwsFormatException);
    });

    test('field rusak menghasilkan FormatException, bukan crash', () {
      expect(() => EncryptionService.decrypt('{"format":"HITUNG_ENCRYPTED_V2"}', 'x'), throwsFormatException);
    });

    test('file format V1 lama tetap bisa didekripsi', () {
      // Membuat file V1 persis seperti algoritma lama (PBKDF2 10.000 + checksum SHA-256).
      final rnd = Random(1);
      final salt = List<int>.generate(16, (_) => rnd.nextInt(256));
      final iv = List<int>.generate(16, (_) => rnd.nextInt(256));
      final hmacPw = Hmac(sha256, utf8.encode('lama'));
      var block = hmacPw.convert([...salt, 0, 0, 0, 1]).bytes;
      final key = List<int>.from(block);
      for (var i = 1; i < 10000; i++) {
        block = hmacPw.convert(block).bytes;
        for (var j = 0; j < key.length; j++) {
          key[j] ^= block[j];
        }
      }
      final plain = utf8.encode('{"v":1}');
      final out = Uint8List(plain.length);
      final hk = Hmac(sha256, key);
      for (var i = 0; i < plain.length; i += 32) {
        final ks = hk.convert([...iv, 0, 0, 0, i ~/ 32]).bytes;
        for (var j = 0; j < min(32, plain.length - i); j++) {
          out[i + j] = plain[i + j] ^ ks[j];
        }
      }
      String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
      final v1 = jsonEncode({
        'format': 'HITUNG_ENCRYPTED_V1',
        'salt': hex(salt),
        'iv': hex(iv),
        'ciphertext': base64Encode(out),
        'checksum': sha256.convert(plain).toString(),
      });
      expect(EncryptionService.decrypt(v1, 'lama'), '{"v":1}');
    });
  });

  group('Backup otomatis terjadwal', () {
    test('tidak berjalan bila nonaktif atau belum 24 jam', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final service = JsonBackupService(db);
      expect(await service.runScheduledAutoBackup(prefs), isNull);

      final now = DateTime(2026, 10, 2, 9);
      await prefs.setBool(AppConstants.prefAutoBackupEnabled, true);
      await prefs.setInt(AppConstants.prefLastAutoBackupTime, now.subtract(const Duration(hours: 5)).millisecondsSinceEpoch);
      expect(await service.runScheduledAutoBackup(prefs, now: now), isNull);
    });
  });

  group('Notifikasi anggaran', () {
    test('setiap ambang hanya sekali per bulan, dan bulan lain tidak memicu', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final sent = <int>[];
      final checker = BudgetAlertChecker(db, prefs, notify: ({
        required String categoryOrGlobal,
        required int percentage,
        required int current,
        required int limit,
      }) async =>
          sent.add(percentage));
      final now = DateTime.now();
      // Anggaran Makanan bawaan = Rp 2.000.000.
      Future<void> spend(String id, int amount, {DateTime? date}) async {
        await db.createTransaction(TransactionsCompanion(
          id: Value(id),
          walletId: const Value('primary_wallet'),
          categoryId: const Value('cat_expense_food'),
          amount: Value(amount),
          type: const Value('EXPENSE'),
          transactionDate: Value(date ?? now),
          createdAt: Value(now),
        ));
        await checker.check(categoryId: 'cat_expense_food', transactionDate: date ?? now, now: now);
      }

      await spend('a', 1700000); // 85% -> notifikasi 80%
      await spend('b', 50000); // 87% -> tidak berulang
      await spend('c', 300000); // 102% -> notifikasi 100%
      await spend('d', 10000); // tetap >100% -> tidak berulang
      expect(sent, [85, 102]);

      await spend('old', 10000, date: DateTime(now.year, now.month - 1, 5)); // bulan lalu
      expect(sent, [85, 102]);
    });
  });

  group('Pencarian', () {
    Future<List<String>> search({String? q, DateTime? start, DateTime? end}) async {
      final items = await db.watchFilteredTransactions(queryText: q, startDate: start, endDate: end).first;
      return items.map((i) => i.transaction.id).toList();
    }

    Future<void> add(String id, {String? note, DateTime? date, String type = 'EXPENSE', String? toWallet}) {
      return db.createTransaction(TransactionsCompanion(
        id: Value(id),
        walletId: const Value('primary_wallet'),
        toWalletId: Value(toWallet),
        categoryId: Value(type == 'TRANSFER' ? null : 'cat_expense_food'),
        amount: const Value(1000),
        type: Value(type),
        note: Value(note),
        transactionDate: Value(date ?? DateTime(2026, 10, 10, 12)),
        createdAt: Value(DateTime(2026, 10, 10)),
      ));
    }

    test('% dan _ dicari sebagai teks, bukan wildcard', () async {
      await add('t1', note: 'diskon 50%');
      await add('t2', note: 'biasa');
      expect(await search(q: '%'), ['t1']);
      expect(await search(q: '_'), isEmpty);
    });

    test('tanggal akhir mencakup seluruh hari', () async {
      await add('pagi', date: DateTime(2026, 10, 10, 8));
      await add('malam', date: DateTime(2026, 10, 10, 22));
      await add('besok', date: DateTime(2026, 10, 11, 1));
      final ids = await search(start: DateTime(2026, 10, 10), end: DateTime(2026, 10, 10));
      expect(ids.toSet(), {'pagi', 'malam'});
    });

    test('nama dompet tujuan transfer ikut dicari', () async {
      await add('tf', type: 'TRANSFER', toWallet: 'w2');
      expect(await search(q: 'bank'), ['tf']);
    });
  });

  group('Laporan PDF', () {
    test('karakter di luar font diganti, bukan tercetak sebagai kotak', () async {
      final service = PdfReportService();
      await service.loadTheme();
      // Emoji tidak ada di font -> dibuang; karakter yang didukung font (→) dipertahankan.
      expect(service.clean('Kopi ☕ → Bank'), 'Kopi → Bank');
      expect(service.clean('Makan 日本 Siang'), 'Makan Siang');
      expect(service.clean('🍜'), '-');
      expect(service.clean('Café'), 'Café');
    });
  });
}
