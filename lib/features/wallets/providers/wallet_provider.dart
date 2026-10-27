import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class WalletController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  WalletController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> createWallet({
    required String name,
    required int initialBalance,
    required String iconName,
    required String colorHex,
    String walletType = 'E_WALLET', // 'BANK', 'E_WALLET', 'SAVINGS', 'CASH'
    String institutionCode = 'CUSTOM',
    int? targetAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      final id = const Uuid().v4();
      await db.insertWallet(WalletsCompanion(
        id: Value(id),
        name: Value(name.trim()),
        initialBalance: Value(initialBalance),
        currentBalance: Value(initialBalance),
        iconName: Value(iconName),
        colorHex: Value(colorHex),
        isArchived: const Value(false),
        createdAt: Value(DateTime.now()),
        walletType: Value(walletType),
        institutionCode: Value(institutionCode),
        targetAmount: Value(targetAmount),
      ));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateWallet({
    required String id,
    required String name,
    required String iconName,
    required String colorHex,
    String? walletType,
    String? institutionCode,
    int? targetAmount,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      final current = await db.getWalletById(id);
      if (current == null) return false;

      await db.updateWallet(WalletsCompanion(
        id: Value(id),
        name: Value(name.trim()),
        initialBalance: Value(current.initialBalance),
        currentBalance: Value(current.currentBalance),
        iconName: Value(iconName),
        colorHex: Value(colorHex),
        isArchived: Value(current.isArchived),
        createdAt: Value(current.createdAt),
        walletType: Value(walletType ?? current.walletType),
        institutionCode: Value(institutionCode ?? current.institutionCode),
        // Diset langsung (bukan `?? current`) agar target tabungan bisa dihapus.
        targetAmount: Value(targetAmount),
      ));
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Soft delete (PRD Rule 5: isArchived = true)
  Future<bool> archiveWallet(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      // Validasi: Jangan arsipkan jika ini satu-satunya dompet aktif
      final active = await db.getActiveWallets();
      if (active.length <= 1) {
        throw Exception('Tidak bisa mengarsipkan dompet terakhir yang aktif');
      }

      await db.archiveWallet(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Pulihkan dompet (Feature 3)
  Future<bool> unarchiveWallet(String id) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      await db.unarchiveWallet(id);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  // Penyesuaian / koreksi selisih saldo dengan rekening asli (Feature 3)
  Future<bool> adjustBalance({
    required String walletId,
    required int actualBalance,
    String? note,
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      await db.adjustWalletBalance(
        walletId: walletId,
        actualBalance: actualBalance,
        note: note,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final walletControllerProvider = StateNotifierProvider<WalletController, AsyncValue<void>>((ref) {
  return WalletController(ref);
});

final archivedWalletsStreamProvider = StreamProvider<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchArchivedWallets();
});

// Filter state provider for Home Hero Segmented Pill Switcher
enum HeroWalletFilter {
  all,
  daily,
  savings,
}

final heroWalletFilterProvider = StateProvider<HeroWalletFilter>((ref) {
  return HeroWalletFilter.all;
});
