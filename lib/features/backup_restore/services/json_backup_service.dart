import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import 'encryption_service.dart';
import 'export_file_utils.dart';

class JsonBackupService {
  final AppDatabase db;

  JsonBackupService(this.db);

  /// Ekspor cadangan JSON. Jika [password] diisi, file akan dienkripsi (Feature 5).
  Future<bool> exportJson({String? password}) async {
    try {
      final data = await db.exportDatabaseJson();
      String outputString = const JsonEncoder.withIndent('  ').convert(data);

      // Kata sandi dipakai persis seperti diketik (tidak di-trim), sama seperti saat dekripsi.
      final isEncrypted = password != null && password.isNotEmpty;
      if (isEncrypted) {
        outputString = await EncryptionService.encryptAsync(outputString, password);
      }

      final tempDir = await getTemporaryDirectory();
      await ExportFileUtils.cleanOldExports(tempDir, 'hitung_backup_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = isEncrypted
          ? 'hitung_backup_${timestamp}_enc.json'
          : 'hitung_backup_$timestamp.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(outputString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: isEncrypted ? 'Cadangan Terenkripsi HITUNG' : 'Cadangan Data HITUNG',
        text: isEncrypted
            ? 'File cadangan data terenkripsi HITUNG (${DateTime.now().toString().split('.')[0]}). Butuh kata sandi untuk memulihkan.'
            : 'File cadangan data aplikasi HITUNG (${DateTime.now().toString().split('.')[0]}).',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Membuat cadangan otomatis lokal (Feature 5) ke dokumen aplikasi.
  /// Menyimpan maksimal 3 file cadangan rotasi.
  Future<File?> performAutoBackup() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final data = await db.exportDatabaseJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${backupDir.path}/autobackup_$timestamp.json');
      await file.writeAsString(jsonString);

      // Rotasi: hapus backup lama jika lebih dari 3
      final allFiles = backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('autobackup_'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      if (allFiles.length > 3) {
        for (var i = 3; i < allFiles.length; i++) {
          try {
            await allFiles[i].delete();
          } catch (_) {}
        }
      }

      return file;
    } catch (_) {
      return null;
    }
  }

  /// Menjalankan backup otomatis bila diaktifkan dan backup terakhir sudah lebih dari 24 jam.
  /// Mengembalikan file backup yang dibuat, atau null bila tidak perlu/ gagal.
  Future<File?> runScheduledAutoBackup(SharedPreferences prefs, {DateTime? now}) async {
    if (!(prefs.getBool(AppConstants.prefAutoBackupEnabled) ?? false)) return null;
    final current = now ?? DateTime.now();
    final lastMs = prefs.getInt(AppConstants.prefLastAutoBackupTime) ?? 0;
    if (current.difference(DateTime.fromMillisecondsSinceEpoch(lastMs)) < const Duration(hours: 24)) {
      return null;
    }
    final file = await performAutoBackup();
    if (file != null) {
      await prefs.setInt(AppConstants.prefLastAutoBackupTime, current.millisecondsSinceEpoch);
    }
    return file;
  }

  /// Menghapus file lama dengan awalan [prefix] di folder backup, menyisakan [keep] terbaru.
  static void _rotate(Directory dir, String prefix, int keep) {
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith(prefix))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (var i = keep; i < files.length; i++) {
      try {
        files[i].deleteSync();
      } catch (_) {}
    }
  }

  /// Membuat snapshot sebelum restore dijalankan (Feature 5)
  Future<File?> performPreRestoreBackup() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final data = await db.exportDatabaseJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${backupDir.path}/pre_restore_snapshot_$timestamp.json');
      await file.writeAsString(jsonString);
      _rotate(backupDir, 'pre_restore_snapshot_', 3);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Mengambil daftar file backup otomatis lokal yang tersedia
  Future<List<File>> getAvailableLocalBackups() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${docsDir.path}/backups');
      if (!await backupDir.exists()) return [];

      return backupDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    } catch (_) {
      return [];
    }
  }

  /// Memilih file JSON dari perangkat dan memulihkannya.
  /// Mendukung file biasa dan file terenkripsi sandi.
  Future<String?> importJson({
    Future<String?> Function()? onPasswordRequested,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'hitung'],
      );

      if (result == null || result.files.single.path == null) {
        return null; // User cancelled
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      return await restoreFromJsonString(content, onPasswordRequested: onPasswordRequested);
    } on FileSystemException {
      return 'File cadangan tidak bisa dibaca.';
    } catch (_) {
      return 'Gagal memulihkan cadangan. Data lama tetap aman dan tidak diubah.';
    }
  }

  /// Memvalidasi dan memulihkan isi file cadangan. Mengembalikan 'SUCCESS' atau pesan error.
  /// Otomatis membuat snapshot data lama sebelum menimpa database (Feature 5).
  Future<String> restoreFromJsonString(
    String content, {
    Future<String?> Function()? onPasswordRequested,
  }) async {
    String actualJson = content;

    // Periksa apakah file terenkripsi
    if (EncryptionService.isEncrypted(content)) {
      if (onPasswordRequested == null) {
        return 'File cadangan terenkripsi, tetapi dialog kata sandi tidak tersedia.';
      }
      final password = await onPasswordRequested();
      if (password == null || password.isEmpty) {
        return 'Pemulihan dibatalkan: kata sandi diperlukan.';
      }

      try {
        actualJson = await EncryptionService.decryptAsync(content, password);
      } on FormatException catch (e) {
        return e.message;
      } catch (_) {
        return 'Gagal mendekripsi file cadangan. Pastikan kata sandi benar.';
      }
    }

    final dynamic parsed;
    try {
      parsed = jsonDecode(actualJson);
    } on FormatException {
      return 'File bukan JSON yang valid.';
    }

    if (parsed is! Map<String, dynamic>) {
      return 'Format file tidak valid. File harus berupa objek JSON cadangan HITUNG.';
    }

    // Validasi schemaVersion
    final version = parsed['schemaVersion'];
    if (version is! int || version < 1 || version > AppConstants.schemaVersion) {
      return 'Versi skema file cadangan ($version) tidak kompatibel dengan aplikasi ini.';
    }

    if (parsed['wallets'] is! List || parsed['categories'] is! List || parsed['transactions'] is! List) {
      return 'Struktur data cadangan tidak lengkap.';
    }

    try {
      // 1. Snapshot otomatis data lama sebelum restore
      await performPreRestoreBackup();

      // 2. Atomic restore (PRD Rule 4)
      await db.atomicRestoreDatabaseJson(parsed);
      return 'SUCCESS';
    } on DataValidationException catch (e) {
      return 'File cadangan tidak valid: ${e.message} Data lama tetap aman.';
    } catch (_) {
      return 'Terjadi kesalahan saat memulihkan data. Data lama tetap aman.';
    }
  }
}
