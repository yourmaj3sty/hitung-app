import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../../core/database/app_database.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/analytics_provider.dart';

class PdfReportService {
  static final PdfReportService _instance = PdfReportService._internal();
  factory PdfReportService() => _instance;
  PdfReportService._internal();

  pw.ThemeData? _theme;
  Set<int> _supportedRunes = const {};

  /// Memuat font Plus Jakarta Sans yang dibundel (font standar PDF tidak mendukung
  /// karakter di luar Latin-1 seperti • → atau huruf beraksen tertentu).
  Future<pw.ThemeData> loadTheme() async {
    if (_theme != null) return _theme!;
    final regular = await rootBundle.load('assets/google_fonts/PlusJakartaSans-Regular.ttf');
    final bold = await rootBundle.load('assets/google_fonts/PlusJakartaSans-Bold.ttf');
    _supportedRunes = TtfParser(regular).charToGlyphIndexMap.keys.toSet();
    return _theme = pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
  }

  static const Map<int, String> _replacements = {
    0x2192: '->', // →
    0x2190: '<-', // ←
    0x2022: '-', // •
    0x2726: '*', // ✦
  };

  /// Mengganti karakter yang tidak ada di font (mis. emoji) agar tidak tercetak sebagai kotak.
  String clean(String text) {
    if (_supportedRunes.isEmpty) return text;
    final out = StringBuffer();
    for (final rune in text.runes) {
      if (_supportedRunes.contains(rune) || rune == 0x20) {
        out.writeCharCode(rune);
      } else if (_replacements.containsKey(rune)) {
        out.write(_replacements[rune]);
      }
      // Karakter lain (emoji, aksara non-Latin) dilewati.
    }
    final result = out.toString().replaceAll(RegExp(r' {2,}'), ' ').trim();
    return result.isEmpty ? '-' : result;
  }

  Future<void> exportAndShareReport({
    required DateTime month,
    required List<TransactionItem> transactions,
    required List<CategoryAnalyticsItem> expenseCategories,
    required List<CategoryAnalyticsItem> incomeCategories,
    required int totalIncome,
    required int totalExpense,
  }) async {
    final theme = await loadTheme();
    final pdf = pw.Document(theme: theme);
    final netSavings = totalIncome - totalExpense;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'HITUNG.',
                      style: pw.TextStyle(
                        fontSize: 26,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.deepPurple700,
                      ),
                    ),
                    pw.Text(
                      'Laporan Keuangan Bulanan',
                      style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      DateFormatter.formatMonthYear(month),
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      'Dibuat: ${DateFormatter.formatShortDate(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // Summary Cards Box
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(
                    'Total Pemasukan',
                    CurrencyFormatter.formatRupiah(totalIncome),
                    PdfColors.green700,
                  ),
                  _buildSummaryItem(
                    'Total Pengeluaran',
                    CurrencyFormatter.formatRupiah(totalExpense),
                    PdfColors.red700,
                  ),
                  _buildSummaryItem(
                    'Saldo Bersih',
                    '${netSavings >= 0 ? '+' : ''}${CurrencyFormatter.formatRupiah(netSavings)}',
                    netSavings >= 0 ? PdfColors.green800 : PdfColors.red800,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Section: Pengeluaran per Kategori
            pw.Text(
              'Rincian Pengeluaran Berdasarkan Kategori',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (expenseCategories.isEmpty)
              pw.Text('Tidak ada pengeluaran pada periode ini.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Kategori', 'Transaksi', 'Porsi', 'Total Nominal'],
                data: expenseCategories.map((c) {
                  return [
                    clean(c.category.name),
                    '${c.transactionCount}x',
                    '${c.percentage}%',
                    CurrencyFormatter.formatRupiah(c.totalAmount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellHeight: 22,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
              ),
            pw.SizedBox(height: 20),

            // Section: Pemasukan per Kategori
            pw.Text(
              'Rincian Pemasukan Berdasarkan Kategori',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (incomeCategories.isEmpty)
              pw.Text('Tidak ada pemasukan pada periode ini.',
                  style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Kategori', 'Transaksi', 'Porsi', 'Total Nominal'],
                data: incomeCategories.map((c) {
                  return [
                    clean(c.category.name),
                    '${c.transactionCount}x',
                    '${c.percentage}%',
                    CurrencyFormatter.formatRupiah(c.totalAmount),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellHeight: 22,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.center,
                  3: pw.Alignment.centerRight,
                },
              ),
            pw.SizedBox(height: 24),

            // Section: Daftar Transaksi Terkini
            pw.Text(
              'Daftar Transaksi (Maksimal 30 Terkini)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (transactions.isEmpty)
              pw.Text('Belum ada transaksi.', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600))
            else
              pw.TableHelper.fromTextArray(
                headers: ['Tanggal', 'Jenis', 'Dompet', 'Kategori / Keterangan', 'Nominal'],
                // Semua transaksi dicetak; tabel otomatis berlanjut ke halaman berikutnya.
                data: transactions.map((item) {
                  final tx = item.transaction;
                  final isExp = tx.type == 'EXPENSE';
                  final isInc = tx.type == 'INCOME';
                  final typeLabel = isExp ? 'Keluar' : (isInc ? 'Masuk' : 'Transfer');
                  final catOrNote = clean(item.category?.name ?? tx.note ?? '-');
                  return [
                    DateFormatter.formatShortDate(tx.transactionDate),
                    typeLabel,
                    clean(item.wallet.name),
                    catOrNote,
                    '${isExp ? '-' : (isInc ? '+' : '')}${CurrencyFormatter.formatRupiah(tx.amount)}',
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellHeight: 20,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.centerLeft,
                  4: pw.Alignment.centerRight,
                },
              ),
            pw.SizedBox(height: 24),

            // Footer note
            pw.Center(
              child: pw.Text(
                'Dihasilkan secara otomatis oleh HITUNG App - Offline-First & Privasi Terjaga',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500),
              ),
            ),
          ];
        },
      ),
    );

    final outputDir = await getTemporaryDirectory();
    final fileName = 'hitung_laporan_${month.year}_${month.month}.pdf';
    final filePath = p.join(outputDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Laporan Keuangan HITUNG - ${DateFormatter.formatMonthYear(month)}',
      subject: 'Laporan Keuangan HITUNG',
    );
  }

  pw.Widget _buildSummaryItem(String title, String value, PdfColor valueColor) {
    return pw.Column(
      children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: valueColor),
        ),
      ],
    );
  }
}
