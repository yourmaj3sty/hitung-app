import 'dart:io';

/// Utilitas file ekspor sementara (JSON/CSV) di folder temp.
class ExportFileUtils {
  /// Menghapus file ekspor lama dengan awalan [prefix] yang lebih tua dari [maxAge].
  /// File terbaru tidak langsung dihapus karena aplikasi tujuan berbagi (Drive, WhatsApp)
  /// bisa saja masih membacanya setelah dialog berbagi ditutup.
  static Future<void> cleanOldExports(
    Directory dir,
    String prefix, {
    Duration maxAge = const Duration(minutes: 30),
  }) async {
    try {
      final now = DateTime.now();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (!name.startsWith(prefix)) continue;
        final modified = await entity.lastModified();
        if (now.difference(modified) > maxAge) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Pembersihan bersifat best-effort; kegagalan tidak boleh membatalkan ekspor.
    }
  }

  /// Mengubah nilai menjadi sel CSV yang aman:
  /// - selalu diapit tanda kutip dan kutip di dalamnya digandakan;
  /// - teks yang diawali = + - @ (atau tab/CR) diberi awalan ' agar Excel/Sheets
  ///   tidak mengeksekusinya sebagai rumus (CSV/formula injection).
  static String csvCell(String? value) {
    var v = value ?? '';
    if (v.isNotEmpty && '=+-@\t\r'.contains(v[0])) {
      v = "'$v";
    }
    return '"${v.replaceAll('"', '""')}"';
  }
}
