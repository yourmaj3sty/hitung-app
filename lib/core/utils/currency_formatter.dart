import 'dart:ui';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Format integer rupiah to display string e.g. Rp 150.000 or -Rp 75.000 (no decimals)
  static String format(int amount, {bool includeSymbol = true, bool showSign = false}) {
    final absVal = amount.abs();
    final formatter = NumberFormat('#,###', 'id_ID');
    final formattedNumber = formatter.format(absVal).replaceAll(',', '.');

    final prefix = includeSymbol ? 'Rp ' : '';
    if (showSign && amount > 0) {
      return '+$prefix$formattedNumber';
    } else if (amount < 0) {
      return '-$prefix$formattedNumber';
    }
    return '$prefix$formattedNumber';
  }

  // Convenience alias for standard Rupiah formatting
  static String formatRupiah(int amount) => format(amount);

  // Parse formatted string back to integer Rupiah
  static int parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return 0;
    return int.tryParse(cleaned) ?? 0;
  }

  // Standard tabular figures font features list
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];
}
