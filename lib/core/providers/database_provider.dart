import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() {
    db.close();
  });
  return db;
});

// Stream provider for active wallets
final activeWalletsStreamProvider = StreamProvider<List<Wallet>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveWallets();
});

// Stream provider for active categories
final activeCategoriesStreamProvider = StreamProvider.family<List<Category>, String?>((ref, type) {
  final db = ref.watch(databaseProvider);
  return db.watchActiveCategories(type: type);
});
