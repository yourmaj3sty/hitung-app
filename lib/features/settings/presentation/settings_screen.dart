import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/widgets/app_logo.dart';
import '../../backup_restore/presentation/backup_restore_screen.dart';
import '../../categories/presentation/category_management_screen.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../recurring/presentation/recurring_transactions_screen.dart';
import '../../wallets/presentation/wallets_screen.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(sharedPreferencesProvider);
    final isBiometricEnabled = ref.watch(isBiometricEnabledProvider);
    final isBiometricSupported = ref.watch(isBiometricSupportedProvider).value ?? true;
    final isPinEnabled = ref.watch(isPinEnabledProvider);
    final isPrivacyEnabled = ref.watch(isPrivacyScreenEnabledProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    final dailyReminderEnabled = prefs.getBool(AppConstants.prefDailyReminderEnabled) ?? false;
    final reminderHour = prefs.getInt(AppConstants.prefDailyReminderHour) ?? 20;
    final reminderMinute = prefs.getInt(AppConstants.prefDailyReminderMinute) ?? 0;
    final budgetAlertEnabled = prefs.getBool(AppConstants.prefBudgetAlertEnabled) ?? true;

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

          // Tampilan & Tema (Feature 9)
          const Text('Tampilan & Tema', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
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
                      color: AppColors.gopayBlueLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      currentThemeMode == ThemeMode.dark
                          ? LucideIcons.moon
                          : (currentThemeMode == ThemeMode.light ? LucideIcons.sun : LucideIcons.smartphone),
                      color: AppColors.gopayBlue,
                      size: 20,
                    ),
                  ),
                  title: const Text('Tema Aplikasi', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    currentThemeMode == ThemeMode.dark
                        ? 'Mode Gelap Aktif'
                        : (currentThemeMode == ThemeMode.light ? 'Mode Terang Aktif' : 'Mengikuti Pengaturan Sistem'),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: DropdownButton<ThemeMode>(
                    value: currentThemeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: ThemeMode.system, child: Text('Sistem')),
                      DropdownMenuItem(value: ThemeMode.light, child: Text('Terang')),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text('Gelap')),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(settingsControllerProvider.notifier).setThemeMode(mode);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Keamanan Section (Feature 9)
          const Text('Keamanan & Privasi', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
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
                // Biometric switch
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
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
                const Divider(height: 1, indent: 56),

                // PIN Aplikasi (Cadangan Biometrik)
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.coralRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.keyRound, color: AppColors.coralRed, size: 20),
                  ),
                  title: const Text('PIN Aplikasi (Cadangan Biometrik)', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    isPinEnabled ? 'PIN Aktif • Ketuk untuk ubah atau hapus' : 'Belum diatur • Ketuk untuk buat PIN',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () => _showPinSettingsDialog(context, ref, isPinEnabled),
                ),
                const Divider(height: 1, indent: 56),

                // Privacy Screen Switch
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gojekGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.shieldCheck, color: AppColors.gojekGreen, size: 20),
                  ),
                  title: const Text(
                    'Privacy Screen (App Switcher)',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Sembunyikan data saldo saat aplikasi diminimalkan.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  value: isPrivacyEnabled,
                  activeColor: AppColors.gojekGreen,
                  onChanged: (val) {
                    ref.read(settingsControllerProvider.notifier).togglePrivacyScreen(val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Notifikasi & Pengingat (Feature 6 & 7)
          const Text('Notifikasi & Pengingat', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
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
                // Daily Reminder
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.warmOrange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.bellRing, color: AppColors.warmOrange, size: 20),
                  ),
                  title: const Text(
                    'Pengingat Catat Harian',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    dailyReminderEnabled
                        ? 'Aktif pada pukul ${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}'
                        : 'Mengingatkan untuk mencatat pengeluaran setiap hari.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  value: dailyReminderEnabled,
                  activeColor: AppColors.warmOrange,
                  onChanged: (val) async {
                    if (val) {
                      final hasPerm = await NotificationService().requestPermissions();
                      if (!hasPerm && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Izin notifikasi tidak diberikan.')),
                        );
                        return;
                      }
                      await prefs.setBool(AppConstants.prefDailyReminderEnabled, true);
                      await NotificationService().scheduleDailyReminder(
                        hour: reminderHour,
                        minute: reminderMinute,
                      );
                    } else {
                      await prefs.setBool(AppConstants.prefDailyReminderEnabled, false);
                      await NotificationService().cancelDailyReminder();
                    }
                    (ref as dynamic).refresh(sharedPreferencesProvider);
                  },
                ),
                if (dailyReminderEnabled) ...[
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const SizedBox(width: 40),
                    title: const Text('Atur Waktu Pengingat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    trailing: Text(
                      '${reminderHour.toString().padLeft(2, '0')}:${reminderMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.warmOrange),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(hour: reminderHour, minute: reminderMinute),
                      );
                      if (picked != null) {
                        await prefs.setInt(AppConstants.prefDailyReminderHour, picked.hour);
                        await prefs.setInt(AppConstants.prefDailyReminderMinute, picked.minute);
                        await NotificationService().scheduleDailyReminder(
                          hour: picked.hour,
                          minute: picked.minute,
                        );
                        (ref as dynamic).refresh(sharedPreferencesProvider);
                      }
                    },
                  ),
                ],
                const Divider(height: 1, indent: 56),

                // Budget Alerts
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.coralRed.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.alertTriangle, color: AppColors.coralRed, size: 20),
                  ),
                  title: const Text(
                    'Peringatan Anggaran (80% & 100%)',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Notifikasi otomatis saat pengeluaran mendekati batas.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  value: budgetAlertEnabled,
                  activeColor: AppColors.coralRed,
                  onChanged: (val) async {
                    if (val) {
                      await NotificationService().requestPermissions();
                    }
                    await prefs.setBool(AppConstants.prefBudgetAlertEnabled, val);
                    (ref as dynamic).refresh(sharedPreferencesProvider);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Data & Keuangan Section (Feature 2, 3, 5, 6)
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
                  title: const Text('Kelola Dompet & Rekening', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Koreksi saldo, pulihkan dompet arsip, dsb', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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
                      color: AppColors.gojekGreen.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.tags, color: AppColors.gojekGreen, size: 20),
                  ),
                  title: const Text('Kelola Kategori', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Edit nama, ikon, anggaran, atau hapus kategori', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CategoryManagementScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.gopayBlue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.repeat, color: AppColors.gopayBlue, size: 20),
                  ),
                  title: const Text('Transaksi Berulang', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Atur otomatisasi gaji, wifi, dan langganan', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecurringTransactionsScreen()),
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
                  title: const Text('Cadangan & Pemulihan Data', style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Backup terenkripsi sandi, otomatis lokal, restore', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
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

  void _showPinSettingsDialog(BuildContext context, WidgetRef ref, bool isPinEnabled) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(isPinEnabled ? 'Atur / Ubah PIN Aplikasi' : 'Buat PIN Aplikasi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isPinEnabled
                    ? 'Masukkan PIN baru (4-6 angka) atau hapus PIN untuk menonaktifkan.'
                    : 'PIN ini akan digunakan sebagai cadangan bila biometrik gagal.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  hintText: 'PIN Baru',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            if (isPinEnabled)
              TextButton(
                onPressed: () async {
                  await ref.read(settingsControllerProvider.notifier).removeAppPin();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Hapus PIN', style: TextStyle(color: AppColors.coralRed)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                if (pin.length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN minimal 4 angka.')),
                  );
                  return;
                }
                await ref.read(settingsControllerProvider.notifier).setAppPin(pin);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gojekGreen),
              child: const Text('Simpan PIN', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
