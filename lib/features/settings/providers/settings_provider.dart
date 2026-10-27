import 'package:flutter/material.dart';
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

final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final val = prefs.getString(AppConstants.prefThemeMode);
  switch (val) {
    case 'dark':
      return ThemeMode.dark;
    case 'light':
      return ThemeMode.light;
    default:
      return ThemeMode.system;
  }
});

final isBiometricEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefBiometricEnabled) ?? false;
});

final isPinEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefPinEnabled) ?? false;
});

final isPrivacyScreenEnabledProvider = StateProvider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool(AppConstants.prefPrivacyScreenEnabled) ?? true;
});

// App lock state (true when biometric or PIN is enabled and user is locked out)
final isAppLockedProvider = StateProvider<bool>((ref) => false);

// Flag to prevent Android system biometric dialog from triggering lifecycle relock
final isAuthenticatingProvider = StateProvider<bool>((ref) => false);

class SettingsController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SettingsController(this._ref) : super(const AsyncValue.data(null));

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final strVal = mode == ThemeMode.dark ? 'dark' : (mode == ThemeMode.light ? 'light' : 'system');
    await prefs.setString(AppConstants.prefThemeMode, strVal);
    _ref.read(themeModeProvider.notifier).state = mode;
  }

  Future<void> togglePrivacyScreen(bool enabled) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.prefPrivacyScreenEnabled, enabled);
    _ref.read(isPrivacyScreenEnabledProvider.notifier).state = enabled;
  }

  Future<void> setAppPin(String pin) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.prefAppPin, pin);
    await prefs.setBool(AppConstants.prefPinEnabled, true);
    _ref.read(isPinEnabledProvider.notifier).state = true;
  }

  Future<void> removeAppPin() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(AppConstants.prefAppPin);
    await prefs.setBool(AppConstants.prefPinEnabled, false);
    _ref.read(isPinEnabledProvider.notifier).state = false;
  }

  bool verifyAppPin(String enteredPin) {
    final prefs = _ref.read(sharedPreferencesProvider);
    final savedPin = prefs.getString(AppConstants.prefAppPin);
    if (savedPin != null && savedPin == enteredPin) {
      _ref.read(isAppLockedProvider.notifier).state = false;
      return true;
    }
    return false;
  }

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
