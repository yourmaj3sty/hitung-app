import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class ReceiptStorageService {
  static final ReceiptStorageService _instance = ReceiptStorageService._internal();
  factory ReceiptStorageService() => _instance;
  ReceiptStorageService._internal();

  /// Menyimpan file foto struk ke folder lokal aplikasi: `<AppDocDir>/receipts/`
  Future<String> saveReceipt(String sourcePath) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'receipt_${const Uuid().v4()}$ext';
    final destinationPath = p.join(receiptsDir.path, fileName);

    final sourceFile = File(sourcePath);
    await sourceFile.copy(destinationPath);
    return destinationPath;
  }

  /// Menghapus file foto struk jika ada
  Future<void> deleteReceipt(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
