import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/app_database.dart';
import 'export_file_utils.dart';

class JsonBackupService {
  final AppDatabase db;

  JsonBackupService(this.db);

  // FR-07: Export .json mencakup seluruh tabel (wallets, categories, transactions)
  Future<bool> exportJson() async {
    try {
      final data = await db.exportDatabaseJson();
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final tempDir = await getTemporaryDirectory();
      await ExportFileUtils.cleanOldExports(tempDir, 'hitung_backup_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/hitung_backup_$timestamp.json');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Cadangan Data HITUNG',
        text: 'File cadangan data aplikasi HITUNG (${DateTime.now().toString().split('.')[0]}).',
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // FR-07: Import .json memvalidasi schemaVersion & menggantikan data secara atomik
  Future<String?> importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return null; // User cancelled
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      return await restoreFromJsonString(content);
    } on FileSystemException {
      return 'File cadangan tidak bisa dibaca.';
    } catch (_) {
      return 'Gagal memulihkan cadangan. Data lama tetap aman dan tidak diubah.';
    }
  }

  /// Memvalidasi dan memulihkan isi file cadangan. Mengembalikan 'SUCCESS' atau pesan error.
  /// Seluruh validasi terjadi sebelum data lama dihapus, jadi data lama aman jika gagal.
  Future<String> restoreFromJsonString(String content) async {
    final dynamic parsed;
    try {
      parsed = jsonDecode(content);
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
      // Atomic restore (PRD Rule 4)
      await db.atomicRestoreDatabaseJson(parsed);
      return 'SUCCESS';
    } on DataValidationException catch (e) {
      return 'File cadangan tidak valid: ${e.message} Data lama tetap aman.';
    }
  }
}
