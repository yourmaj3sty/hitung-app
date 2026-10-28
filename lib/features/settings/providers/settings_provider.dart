import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:local_auth/local_auth.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/privacy_guard.dart';
import '../../onboarding/providers/onboarding_provider.dart';

final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

final isBiometricSupportedProvider = FutureProvider<bool>((ref) async {
  if (kIsWeb) return false;
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
    await PrivacyGuard.setSecure(enabled);
  }

  static final RegExp _pinPattern = RegExp(r'^[0-9]{4,6}$');
  static const int _freeAttempts = 5;

  /// PIN disimpan sebagai hash SHA-256 bergaram dengan format `v1$<salt>$<hash>`.
  static String hashPin(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  static bool isValidPin(String pin) => _pinPattern.hasMatch(pin);

  Future<void> setAppPin(String pin) async {
    if (!isValidPin(pin)) throw ArgumentError('PIN harus 4-6 angka.');
    final prefs = _ref.read(sharedPreferencesProvider);
    final random = Random.secure();
    final salt = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await prefs.setString(AppConstants.prefAppPin, 'v1\$$salt\$${hashPin(pin, salt)}');
    await prefs.setBool(AppConstants.prefPinEnabled, true);
    await prefs.remove(AppConstants.prefPinFailedCount);
    await prefs.remove(AppConstants.prefPinLockedUntil);
    _ref.read(isPinEnabledProvider.notifier).state = true;
  }

  Future<void> removeAppPin() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    await prefs.remove(AppConstants.prefAppPin);
    await prefs.setBool(AppConstants.prefPinEnabled, false);
    _ref.read(isPinEnabledProvider.notifier).state = false;
  }

  /// Memverifikasi PIN dengan batas percobaan: setelah 5 kali salah, input dikunci
  /// 30 detik dan durasinya berlipat ganda setiap kesalahan berikutnya (maks. 15 menit).
  Future<PinCheckResult> verifyAppPin(String enteredPin, {DateTime? now}) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final current = now ?? DateTime.now();

    final lockedUntilMs = prefs.getInt(AppConstants.prefPinLockedUntil) ?? 0;
    final lockedUntil = DateTime.fromMillisecondsSinceEpoch(lockedUntilMs);
    if (current.isBefore(lockedUntil)) {
      return PinCheckResult.locked(lockedUntil.difference(current));
    }

    final saved = prefs.getString(AppConstants.prefAppPin);
    if (saved == null) return const PinCheckResult.wrong(0);

    bool ok;
    if (saved.startsWith('v1\$')) {
      final parts = saved.split('\$');
      ok = parts.length == 3 && hashPin(enteredPin, parts[1]) == parts[2];
    } else {
      // PIN lama tersimpan sebagai teks biasa: cocokkan lalu ubah menjadi hash.
      ok = saved == enteredPin;
      if (ok && isValidPin(enteredPin)) await setAppPin(enteredPin);
    }

    if (ok) {
      await prefs.remove(AppConstants.prefPinFailedCount);
      await prefs.remove(AppConstants.prefPinLockedUntil);
      _ref.read(isAppLockedProvider.notifier).state = false;
      return const PinCheckResult.success();
    }

    final failed = (prefs.getInt(AppConstants.prefPinFailedCount) ?? 0) + 1;
    await prefs.setInt(AppConstants.prefPinFailedCount, failed);
    if (failed >= _freeAttempts) {
      final factor = 1 << (failed - _freeAttempts).clamp(0, 5); // 30 dtk .. 16 mnt
      final lock = Duration(seconds: min(30 * factor, 15 * 60));
      await prefs.setInt(AppConstants.prefPinLockedUntil, current.add(lock).millisecondsSinceEpoch);
      return PinCheckResult.locked(lock);
    }
    return PinCheckResult.wrong(_freeAttempts - failed);
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
        // Jika PIN aplikasi aktif, aplikasi TETAP terkunci dan harus dibuka dengan PIN.
        if (!_ref.read(isPinEnabledProvider)) {
          _ref.read(isAppLockedProvider.notifier).state = false;
        }
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

/// Hasil verifikasi PIN.
class PinCheckResult {
  final bool success;
  /// Sisa percobaan sebelum input dikunci sementara.
  final int remainingAttempts;
  /// Lama penguncian bila terlalu banyak percobaan salah.
  final Duration? lockedFor;

  const PinCheckResult.success()
      : success = true,
        remainingAttempts = 0,
        lockedFor = null;
  const PinCheckResult.wrong(this.remainingAttempts)
      : success = false,
        lockedFor = null;
  const PinCheckResult.locked(Duration this.lockedFor)
      : success = false,
        remainingAttempts = 0;

  bool get isLocked => lockedFor != null;
}

final settingsControllerProvider = StateNotifierProvider<SettingsController, AsyncValue<void>>((ref) {
  return SettingsController(ref);
});
