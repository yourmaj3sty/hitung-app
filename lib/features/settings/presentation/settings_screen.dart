import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../backup_restore/presentation/backup_restore_screen.dart';
import '../../wallets/presentation/wallets_screen.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBiometricEnabled = ref.watch(isBiometricEnabledProvider);
    final isBiometricSupported = ref.watch(isBiometricSupportedProvider).value ?? true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // App Brand Header Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                AppLogo(size: 56, showText: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Keamanan Section (FR-08)
          const Text('Keamanan & Privasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.border),
              ),
              child: SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              secondary: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.gopayBlueLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.fingerprint, color: AppColors.gopayBlue, size: 22),
              ),
              title: const Text(
                'Kunci Sidik Jari / Biometrik',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                isBiometricSupported
                    ? 'Kunci aplikasi saat diminimalkan atau dibuka kembali.'
                    : 'Periksa pengaturan sidik jari pada perangkat Anda.',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: isBiometricEnabled,
              activeColor: AppColors.gopayBlue,
              onChanged: (val) async {
                final ok = await ref.read(settingsControllerProvider.notifier).toggleBiometric(val);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Verifikasi biometrik tidak berhasil atau dibatalkan.')),
                  );
                }
              },
            ),
            ),
          ),
          const SizedBox(height: 24),

          // Data & Dompet Section
          const Text('Data & Keuangan', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Material(
            color: AppColors.surface,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.wallet, color: AppColors.infoBlue, size: 20),
                  ),
                  title: const Text('Kelola Dompet', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Tambah, edit, atau arsipkan dompet & rekening', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const WalletsScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.hardDrive, color: AppColors.warmOrange, size: 20),
                  ),
                  title: const Text('Cadangan & Pemulihan (JSON / CSV)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Amankan data saat ganti perangkat', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          const Text('Tentang Aplikasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Versi Aplikasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(AppConstants.appVersion, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 10),
                Divider(height: 1),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Arsitektur', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text('100% Offline-First / On-Device', style: TextStyle(color: AppColors.emeraldGreen, fontWeight: FontWeight.w600)),
                  ],
                ),
                SizedBox(height: 10),
                Divider(height: 1),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Bundle ID', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    Text(AppConstants.applicationId, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
