import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
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
            subtitle: 'Mencakup seluruh dompet, kategori, dan transaksi untuk dipulihkan kembali.',
            onTap: _isLoading
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isLoading = true);
                    final ok = await jsonService.exportJson();
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
              final result = await jsonService.importJson();
              if (!mounted) return;
              setState(() => _isLoading = false);

              if (result == 'SUCCESS') {
                // Filter dompet & daftar "sedang dihapus" bisa merujuk data lama.
                ref.read(selectedWalletFilterProvider.notifier).state = null;
                ref.read(pendingDeletedTxIdsProvider.notifier).state = const <String>{};
                messenger.showSnackBar(
                  const SnackBar(content: Text('Data cadangan berhasil dipulihkan secara utuh!')),
                );
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
