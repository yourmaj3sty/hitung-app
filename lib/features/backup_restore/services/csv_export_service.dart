import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/date_formatter.dart';
import 'export_file_utils.dart';

class CsvExportService {
  final AppDatabase db;

  CsvExportService(this.db);

  // FR-07: Export .csv menghasilkan tabel transaksi yang rapi untuk Excel
  Future<bool> exportCsv() async {
    try {
      final toWallets = db.alias(db.wallets, 'to_wallet');
      final query = db.select(db.transactions).join([
        innerJoin(db.wallets, db.wallets.id.equalsExp(db.transactions.walletId)),
        leftOuterJoin(toWallets, toWallets.id.equalsExp(db.transactions.toWalletId)),
        leftOuterJoin(db.categories, db.categories.id.equalsExp(db.transactions.categoryId)),
      ])..orderBy([OrderingTerm.desc(db.transactions.transactionDate)]);

      final rows = await query.get();

      final buffer = StringBuffer();
      // Excel-friendly CSV with BOM for proper UTF-8 handling in Excel
      buffer.write('\uFEFF');

      // CSV Header
      buffer.writeln('"ID","Tanggal","Tipe","Kategori","Dompet Asal","Dompet Tujuan","Nominal","Catatan"');

      const cell = ExportFileUtils.csvCell;
      for (final row in rows) {
        final tx = row.readTable(db.transactions);
        final w = row.readTable(db.wallets);
        final toW = row.readTableOrNull(toWallets);
        final c = row.readTableOrNull(db.categories);

        final typeLabel = tx.type == 'EXPENSE'
            ? 'Pengeluaran'
            : tx.type == 'INCOME'
                ? 'Pemasukan'
                : 'Transfer';

        final categoryName = c?.name ?? (tx.type == 'TRANSFER' ? 'Transfer Saldo' : '-');
        final dateStr = DateFormatter.formatIsoDate(tx.transactionDate);

        buffer.writeln([
          cell(tx.id),
          cell(dateStr),
          cell(typeLabel),
          cell(categoryName),
          cell(w.name),
          cell(toW?.name),
          tx.amount.toString(),
          cell(tx.note),
        ].join(','));
      }

      final tempDir = await getTemporaryDirectory();
      await ExportFileUtils.cleanOldExports(tempDir, 'hitung_transaksi_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/hitung_transaksi_$timestamp.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Ekspor Transaksi HITUNG (CSV)',
        text: 'Laporan transaksi keuangan aplikasi HITUNG dalam format CSV/Excel.',
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
