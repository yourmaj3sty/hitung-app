import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../services/csv_export_service.dart';
import '../services/json_backup_service.dart';

class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final jsonService = JsonBackupService(db);
    final csvService = CsvExportService(db);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cadangan & Pemulihan'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.shieldCheck, color: AppColors.emeraldGreen, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '100% Data Tersimpan di Perangkat',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Aplikasi HITUNG tidak menggunakan cloud/server eksternal. Lakukan ekspor cadangan secara berkala agar data tetap aman saat ganti HP.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Ekspor Data', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // Export JSON Tile
          _buildActionTile(
            icon: LucideIcons.fileJson,
            color: AppColors.emeraldGreen,
            title: 'Ekspor Cadangan Lengkap (.json)',
            subtitle: 'Seluruh dompet, kategori, transaksi, dan jadwal berulang. Bisa dikunci dengan kata sandi.',
            onTap: _isLoading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    // null = dibatalkan, '' = tanpa kata sandi.
                    final password = await _askExportPassword(context);
                    if (password == null || !mounted) return;
                    setState(() => _isLoading = true);
                    final ok = await jsonService.exportJson(password: password.isEmpty ? null : password);
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (!ok) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Gagal mengekspor file JSON.')),
                      );
                    }
                  },
          ),
          const SizedBox(height: 10),

          // Export CSV Tile
          _buildActionTile(
            icon: LucideIcons.fileSpreadsheet,
            color: AppColors.infoBlue,
            title: 'Ekspor Transaksi Excel (.csv)',
            subtitle: 'Format tabel rapi untuk dibuka di Microsoft Excel atau Google Spreadsheet.',
            onTap: _isLoading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isLoading = true);
                    final ok = await csvService.exportCsv();
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    if (!ok) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Gagal mengekspor file CSV.')),
                      );
                    }
                  },
          ),
          const SizedBox(height: 24),

          const Text('Pemulihan Data', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          // Import JSON Tile
          _buildActionTile(
            icon: LucideIcons.uploadCloud,
            color: AppColors.warmOrange,
            title: 'Pulihkan dari File Cadangan (.json)',
            subtitle: 'Menggantikan seluruh data aplikasi saat ini dengan data dari file cadangan.',
            onTap: _isLoading ? null : () => _confirmRestore(context, jsonService),
          ),
          const SizedBox(height: 24),

          const Text('Backup Otomatis', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
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
                SwitchListTile(
                  title: const Text('Backup otomatis harian',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _lastAutoBackupLabel(),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  value: ref.watch(sharedPreferencesProvider).getBool(AppConstants.prefAutoBackupEnabled) ?? false,
                  activeColor: AppColors.emeraldGreen,
                  onChanged: _isLoading ? null : (val) => _toggleAutoBackup(val, jsonService),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: const Icon(LucideIcons.history, color: AppColors.infoBlue),
                  title: const Text('Pulihkan dari backup lokal',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Backup otomatis & snapshot sebelum restore (disimpan di perangkat).',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
                  onTap: _isLoading ? null : () => _showLocalBackups(context, jsonService),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _lastAutoBackupLabel() {
    final prefs = ref.read(sharedPreferencesProvider);
    final ms = prefs.getInt(AppConstants.prefLastAutoBackupTime);
    if (ms == null) return 'Menyimpan 3 cadangan terakhir di perangkat, sekali sehari.';
    final t = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return 'Terakhir: ${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  Future<void> _toggleAutoBackup(bool enabled, JsonBackupService service) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final messenger = ScaffoldMessenger.of(context);
    await prefs.setBool(AppConstants.prefAutoBackupEnabled, enabled);
    if (enabled) {
      setState(() => _isLoading = true);
      final file = await service.performAutoBackup();
      if (file != null) {
        await prefs.setInt(AppConstants.prefLastAutoBackupTime, DateTime.now().millisecondsSinceEpoch);
      }
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(SnackBar(
        content: Text(file != null ? 'Backup otomatis aktif. Cadangan pertama sudah dibuat.' : 'Gagal membuat cadangan.'),
      ));
    } else {
      setState(() {});
    }
  }

  void _afterSuccessfulRestore(ScaffoldMessengerState messenger) {
    // Filter dompet & daftar "sedang dihapus" bisa merujuk data lama.
    ref.read(selectedWalletFilterProvider.notifier).state = null;
    ref.read(pendingDeletedTxIdsProvider.notifier).state = const <String>{};
    messenger.showSnackBar(
      const SnackBar(content: Text('Data cadangan berhasil dipulihkan secara utuh!')),
    );
  }

  Future<void> _showLocalBackups(BuildContext context, JsonBackupService service) async {
    final files = await service.getAvailableLocalBackups();
    if (!context.mounted) return;
    final picked = await showModalBottomSheet<File>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: files.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Belum ada backup lokal.', textAlign: TextAlign.center),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final f in files)
                    ListTile(
                      leading: Icon(
                        f.path.contains('pre_restore') ? LucideIcons.shieldAlert : LucideIcons.archive,
                        color: AppColors.infoBlue,
                      ),
                      title: Text(
                        f.path.contains('pre_restore') ? 'Snapshot sebelum restore' : 'Backup otomatis',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(f.lastModifiedSync().toString().split('.').first),
                      onTap: () => Navigator.pop(ctx, f),
                    ),
                ],
              ),
      ),
    );
    if (picked == null || !context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan backup ini?'),
        content: const Text('Data saat ini akan digantikan. Snapshot data saat ini dibuat otomatis lebih dulu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pulihkan')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    String result;
    try {
      result = await service.restoreFromJsonString(await picked.readAsString());
    } catch (_) {
      result = 'File backup tidak bisa dibaca.';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result == 'SUCCESS') {
      _afterSuccessfulRestore(messenger);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(result), backgroundColor: AppColors.coralRed));
    }
  }

  /// Dialog kata sandi ekspor. Mengembalikan null bila dibatalkan, '' bila tanpa kata sandi.
  Future<String?> _askExportPassword(BuildContext context) {
    final pass = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Kunci cadangan dengan kata sandi?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Opsional. Jika diisi, file hanya bisa dipulihkan dengan kata sandi ini. Kata sandi yang lupa tidak bisa dipulihkan.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Kata sandi')),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Ulangi kata sandi', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('Tanpa Sandi')),
            ElevatedButton(
              onPressed: () {
                if (pass.text.length < 6) {
                  setDialogState(() => error = 'Minimal 6 karakter.');
                } else if (pass.text != confirm.text) {
                  setDialogState(() => error = 'Kata sandi tidak sama.');
                } else {
                  Navigator.pop(ctx, pass.text);
                }
              },
              child: const Text('Kunci & Ekspor'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _askRestorePassword(BuildContext context) {
    final pass = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('File cadangan terkunci'),
        content: TextField(
          controller: pass,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Kata sandi cadangan'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, pass.text), child: const Text('Buka')),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.3)),
        ),
        trailing: const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }

  void _confirmRestore(BuildContext context, JsonBackupService jsonService) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pulihkan Data Cadangan?'),
        content: const Text(
          'PENTING: Seluruh data transaksi, dompet, dan kategori yang ada saat ini akan digantikan secara penuh dengan isi file cadangan. Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              setState(() => _isLoading = true);
              final result = await jsonService.importJson(
                onPasswordRequested: () => _askRestorePassword(context),
              );
              if (!mounted) return;
              setState(() => _isLoading = false);

              if (result == 'SUCCESS') {
                _afterSuccessfulRestore(messenger);
              } else if (result != null) {
                messenger.showSnackBar(
                  SnackBar(content: Text(result), backgroundColor: AppColors.coralRed),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.warmOrange, foregroundColor: Colors.white),
            child: const Text('Pilih File & Pulihkan'),
          ),
        ],
      ),
    );
  }
}
