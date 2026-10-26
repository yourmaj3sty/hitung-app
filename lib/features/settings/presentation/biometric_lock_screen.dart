import 'package:flutter/material.dart';
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
    // Auto-prompt biometric on appearance
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final result = await ref.read(settingsControllerProvider.notifier).unlockApp();
    if (!mounted && result != UnlockResult.unavailable) return;
    switch (result) {
      case UnlockResult.success:
        break;
      case UnlockResult.unavailable:
        messenger?.showSnackBar(const SnackBar(
          content: Text('Kunci layar perangkat tidak aktif, jadi kunci aplikasi dinonaktifkan.'),
        ));
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
                  const SizedBox(height: 40),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
