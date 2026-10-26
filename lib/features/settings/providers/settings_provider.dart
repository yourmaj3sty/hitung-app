import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../onboarding/providers/onboarding_provider.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final isBiometricSupportedProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(localAuthProvider);
  try {
    final canCheck = await auth.canCheckBiometrics;
    final isDeviceSupported = await auth.isDeviceSupported();
    final available = await auth.getAvailableBiometrics();
    return canCheck || isDeviceSupported || available.isNotEmpty;
  } catch (_) {
    return true; // Fallback to true so the user can test on hardware
  }
});

final isBiometricEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefBiometricEnabled) ?? false;
});

// App lock state (true when biometric is enabled and user is locked out)
final isAppLockedProvider = StateProvider<bool>((ref) => false);

// Flag to prevent Android system biometric dialog from triggering lifecycle relock
final isAuthenticatingProvider = StateProvider<bool>((ref) => false);

class SettingsController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SettingsController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> toggleBiometric(bool enabled) async {
    final auth = _ref.read(localAuthProvider);
    final prefs = _ref.read(sharedPreferencesProvider);

    _ref.read(isAuthenticatingProvider.notifier).state = true;
    try {
      if (enabled) {
        final authenticated = await auth.authenticate(
          localizedReason: 'Verifikasi sidik jari/kunci untuk mengaktifkan proteksi aplikasi',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false, // Allows device PIN/pattern/fingerprint
          ),
        );
        if (!authenticated) return false;
      }

      await prefs.setBool(AppConstants.prefBiometricEnabled, enabled);
      _ref.read(isBiometricEnabledProvider.notifier).state = enabled;
      return true;
    } catch (_) {
      return false;
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _ref.read(isAuthenticatingProvider.notifier).state = false;
    }
  }

  Future<UnlockResult> unlockApp() async {
    // Cegah dua dialog autentikasi terbuka bersamaan (auto-prompt + tombol).
    if (_ref.read(isAuthenticatingProvider)) return UnlockResult.failed;

    final auth = _ref.read(localAuthProvider);
    _ref.read(isAuthenticatingProvider.notifier).state = true;
    try {
      final authenticated = await auth.authenticate(
        localizedReason: 'Buka kunci aplikasi HITUNG dengan sidik jari',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
      if (authenticated) {
        _ref.read(isAppLockedProvider.notifier).state = false;
        return UnlockResult.success;
      }
      return UnlockResult.failed;
    } on PlatformException catch (e) {
      // Perangkat tidak lagi punya kunci layar/biometrik sama sekali. Tanpa ini pengguna
      // terkunci selamanya. Kunci layar hanya bisa dihapus oleh orang yang sudah tahu
      // PIN perangkat, jadi menonaktifkan kunci aplikasi di sini tidak melemahkan keamanan.
      if (e.code == auth_error.notAvailable ||
          e.code == auth_error.notEnrolled ||
          e.code == auth_error.passcodeNotSet) {
        await _ref.read(sharedPreferencesProvider).setBool(AppConstants.prefBiometricEnabled, false);
        _ref.read(isBiometricEnabledProvider.notifier).state = false;
        _ref.read(isAppLockedProvider.notifier).state = false;
        return UnlockResult.unavailable;
      }
      if (e.code == auth_error.lockedOut || e.code == auth_error.permanentlyLockedOut) {
        return UnlockResult.lockedOut;
      }
      return UnlockResult.failed;
    } catch (_) {
      return UnlockResult.failed;
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      _ref.read(isAuthenticatingProvider.notifier).state = false;
    }
  }
}

enum UnlockResult { success, failed, lockedOut, unavailable }

final settingsControllerProvider = StateNotifierProvider<SettingsController, AsyncValue<void>>((ref) {
  return SettingsController(ref);
});
