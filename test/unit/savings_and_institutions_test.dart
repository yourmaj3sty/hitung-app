import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/constants/institution_presets.dart';
import 'package:hitung/core/database/app_database.dart';

void main() {
  group('InstitutionPresets Tests', () {
    test('Katalog Bank, E-Wallet, dan Tunai terdefinisi lengkap', () {
      expect(InstitutionPresets.banks.length, 9);
      expect(InstitutionPresets.eWallets.length, 6);
      expect(InstitutionPresets.cash.length, 1);
      expect(InstitutionPresets.all.length, 16);
    });

    test('Pencarian preset dengan getByCode', () {
      final bca = InstitutionPresets.getByCode('BCA');
      expect(bca.name, 'BCA');
      expect(bca.shortLabel, 'BCA');
      expect(bca.colorHex, '#0060AF');
      expect(bca.category, InstitutionCategory.bank);

      final jago = InstitutionPresets.getByCode('JAGO');
      expect(jago.name, 'Bank Jago');
      expect(jago.shortLabel, 'Jago');
      expect(jago.colorHex, '#FF6B00');

      final gopay = InstitutionPresets.getByCode('GOPAY');
      expect(gopay.name, 'GoPay');
      expect(gopay.colorHex, '#00AED6');
      expect(gopay.category, InstitutionCategory.eWallet);

      final tunai = InstitutionPresets.getByCode('TUNAI');
      expect(tunai.name, 'Uang Tunai / Cash');
      expect(tunai.colorHex, '#00AA13');
      expect(tunai.category, InstitutionCategory.cash);

      // Fallback for null or unknown code
      final fallback = InstitutionPresets.getByCode('UNKNOWN_CODE');
      expect(fallback.code, 'CUSTOM');
    });
  });

  group('Kantong Tabungan & Progress Math Tests', () {
    test('Perhitungan progress target tabungan berbasis integer/clamped ratio', () {
      const int targetAmount = 5000000; // Rp 5.000.000
      const int currentBalance = 2500000; // Rp 2.500.000

      final double progress = (currentBalance / targetAmount).clamp(0.0, 1.0);
      expect(progress, 0.5);

      final int percentage = (progress * 100).toInt();
      expect(percentage, 50);
    });

    test('Progress clamped pada 1.0 saat saldo melebihi target', () {
      const int targetAmount = 1000000;
      const int currentBalance = 1500000;

      final double progress = (currentBalance / targetAmount).clamp(0.0, 1.0);
      expect(progress, 1.0);
      expect((progress * 100).toInt(), 100);
    });

    test('Backup JSON v2 mengekspor dan memulihkan field tabungan & institusi', () async {
      final db = AppDatabase(NativeDatabase.memory());

      await db.insertWallet(WalletsCompanion(
        id: const Value('wallet_tabungan_1'),
        name: const Value('Upgrade Setup'),
        initialBalance: const Value(500000),
        currentBalance: const Value(500000),
        iconName: const Value('laptop'),
        colorHex: const Value('#00AED6'),
        isArchived: const Value(false),
        createdAt: Value(DateTime.now()),
        walletType: const Value('SAVINGS'),
        institutionCode: const Value('BLU'),
        targetAmount: const Value(10000000),
      ));

      // Saldo 1.200.000 berasal dari transaksi nyata (restore menghitung ulang saldo
      // dari saldo awal + riwayat transaksi).
      await db.createTransaction(TransactionsCompanion(
        id: const Value('tx_setoran_1'),
        walletId: const Value('wallet_tabungan_1'),
        amount: const Value(700000),
        type: const Value('INCOME'),
        transactionDate: Value(DateTime.now()),
        createdAt: Value(DateTime.now()),
      ));

      final exported = await db.exportDatabaseJson();
      expect(exported['schemaVersion'], 2);

      final walletsList = exported['wallets'] as List;
      expect(walletsList.length, 1);
      final w = walletsList.first as Map<String, dynamic>;
      expect(w['walletType'], 'SAVINGS');
      expect(w['institutionCode'], 'BLU');
      expect(w['targetAmount'], 10000000);

      // Create new clean DB and atomic restore
      final db2 = AppDatabase(NativeDatabase.memory());
      await db2.atomicRestoreDatabaseJson(exported);

      final restored = await db2.getWalletById('wallet_tabungan_1');
      expect(restored, isNotNull);
      expect(restored?.name, 'Upgrade Setup');
      expect(restored?.walletType, 'SAVINGS');
      expect(restored?.institutionCode, 'BLU');
      expect(restored?.targetAmount, 10000000);
      expect(restored?.currentBalance, 1200000);

      await db.close();
      await db2.close();
    });

    test('Pemulihan backup v1 kompatibel mundur (fallback nilai default)', () async {
      final db = AppDatabase(NativeDatabase.memory());

      final legacyV1Data = {
        'schemaVersion': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'appName': 'HITUNG',
        'wallets': [
          {
            'id': 'legacy_wallet',
            'name': 'Dompet Lama',
            'initialBalance': 100000,
            'currentBalance': 100000,
            'iconName': 'wallet',
            'colorHex': '#00AA13',
            'isArchived': false,
            'createdAt': DateTime.now().toIso8601String(),
            // No walletType, institutionCode, or targetAmount
          }
        ],
        'categories': [],
        'transactions': [],
      };

      await db.atomicRestoreDatabaseJson(legacyV1Data);

      final restored = await db.getWalletById('legacy_wallet');
      expect(restored, isNotNull);
      expect(restored?.name, 'Dompet Lama');
      expect(restored?.walletType, 'E_WALLET'); // Default fallback
      expect(restored?.institutionCode, 'CUSTOM'); // Default fallback
      expect(restored?.targetAmount, isNull);

      await db.close();
    });
  });
}
