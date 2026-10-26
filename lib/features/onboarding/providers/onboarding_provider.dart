import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/database_provider.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main()');
});

final isOnboardedProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefIsOnboarded) ?? false;
});

class OnboardingController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  OnboardingController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> completeOnboarding({
    required String walletName,
    required int initialBalance,
    required String iconName,
    required String colorHex,
    String walletType = 'E_WALLET',
    String institutionCode = 'CUSTOM',
  }) async {
    state = const AsyncValue.loading();
    try {
      final db = _ref.read(databaseProvider);
      final prefs = _ref.read(sharedPreferencesProvider);

      // Seed database with 10 default categories & primary wallet
      await db.seedInitialData(
        walletName: walletName.trim().isEmpty ? 'Dompet Utama' : walletName.trim(),
        initialBalance: initialBalance,
        walletIcon: iconName,
        walletColorHex: colorHex,
        walletType: walletType,
        institutionCode: institutionCode,
      );

      // Save onboarding flag in SharedPreferences
      await prefs.setBool(AppConstants.prefIsOnboarded, true);
      await prefs.setString(AppConstants.prefLastUsedWalletId, 'primary_wallet');

      _ref.read(isOnboardedProvider.notifier).state = true;
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final onboardingControllerProvider = StateNotifierProvider<OnboardingController, AsyncValue<void>>((ref) {
  return OnboardingController(ref);
});
