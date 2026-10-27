import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_logo.dart';
import '../providers/settings_provider.dart';

class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  String? _message;

  @override
  void initState() {
    super.initState();
    // Biometrik aktif -> langsung minta sidik jari. Hanya PIN -> langsung minta PIN.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(isBiometricEnabledProvider)) {
        _unlock();
      } else if (ref.read(isPinEnabledProvider)) {
        _showPinEntryDialog(context);
      }
    });
  }

  Future<void> _unlock() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(settingsControllerProvider.notifier).unlockApp();
    if (!mounted && result != UnlockResult.unavailable) return;
    switch (result) {
      case UnlockResult.success:
        break;
      case UnlockResult.unavailable:
        if (mounted && ref.read(isPinEnabledProvider)) {
          // Biometrik tidak tersedia lagi, tapi PIN aktif: aplikasi tetap terkunci.
          setState(() => _message = 'Kunci layar perangkat tidak aktif. Buka dengan PIN aplikasi.');
          _showPinEntryDialog(context);
        } else {
          messenger?.showSnackBar(const SnackBar(
            content: Text('Kunci layar perangkat tidak aktif, jadi kunci aplikasi dinonaktifkan.'),
          ));
        }
        break;
      case UnlockResult.lockedOut:
        setState(() => _message = 'Terlalu banyak percobaan. Tunggu sebentar atau buka dengan PIN perangkat.');
        break;
      case UnlockResult.failed:
        setState(() => _message = 'Verifikasi belum berhasil. Ketuk tombol di bawah untuk mencoba lagi.');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBiometricEnabled = ref.watch(isBiometricEnabledProvider);
    final isPinEnabled = ref.watch(isPinEnabledProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppLogo(size: 72, showText: true),
                  const SizedBox(height: 48),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.gopayBlueLight,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gopayBlue.withOpacity(0.3), width: 2),
                    ),
                    child: const Center(
                      child: Icon(
                        LucideIcons.fingerprint,
                        size: 52,
                        color: AppColors.gopayBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Verifikasi Keamanan',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pindai sidik jari Anda atau gunakan kunci layar perangkat untuk membuka aplikasi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _message!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.coralRed, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const SizedBox(height: 36),
                  if (isBiometricEnabled)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _unlock,
                        icon: const Icon(LucideIcons.fingerprint, size: 22),
                        label: const Text(
                          'Pindai Sidik Jari',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gopayBlue,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Opsi Buka dengan PIN Cadangan (Feature 9)
                  if (isPinEnabled)
                    TextButton.icon(
                      onPressed: () => _showPinEntryDialog(context),
                      icon: const Icon(LucideIcons.keyRound, size: 16, color: AppColors.gopayBlue),
                      label: const Text(
                        'Buka dengan PIN Aplikasi',
                        style: TextStyle(
                          color: AppColors.gopayBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPinEntryDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        String? errText;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: const Text('Masukkan PIN Aplikasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Gunakan PIN keamanan yang telah Anda atur sebelumnya.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      hintText: '••••',
                      errorText: errText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () async {
                    final pin = pinController.text.trim();
                    final result = await ref.read(settingsControllerProvider.notifier).verifyAppPin(pin);
                    if (result.success) {
                      if (ctx.mounted) Navigator.pop(ctx);
                      return;
                    }
                    pinController.clear();
                    setDialogState(() {
                      if (result.isLocked) {
                        final secs = result.lockedFor!.inSeconds;
                        errText = 'Terlalu banyak percobaan. Coba lagi dalam $secs detik.';
                      } else {
                        errText = 'PIN salah. Sisa ${result.remainingAttempts} percobaan.';
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.gopayBlue),
                  child: const Text('Buka', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
