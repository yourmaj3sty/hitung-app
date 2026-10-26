import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import 'currency_formatter.dart';

/// Memformat input nominal menjadi pemisah ribuan (150.000) saat mengetik,
/// membatasi jumlah digit, dan menjaga posisi kursor tetap wajar.
class RupiahInputFormatter extends TextInputFormatter {
  final int maxDigits;

  const RupiahInputFormatter({this.maxDigits = AppConstants.maxInputDigits});

  static final RegExp _nonDigit = RegExp(r'[^0-9]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }
    // Tolak input yang melebihi batas digit (mis. paste angka sangat panjang).
    if (digits.length > maxDigits) return oldValue;

    final formatted = CurrencyFormatter.format(int.parse(digits), includeSymbol: false);

    // Pertahankan jumlah digit di kanan kursor agar kursor tidak lompat ke akhir.
    final cursor = newValue.selection.isValid
        ? newValue.selection.end.clamp(0, newValue.text.length)
        : newValue.text.length;
    final digitsAfterCursor = newValue.text.substring(cursor).replaceAll(_nonDigit, '').length;

    var offset = formatted.length;
    var seen = 0;
    while (offset > 0 && seen < digitsAfterCursor) {
      offset--;
      if (_isDigit(formatted.codeUnitAt(offset))) seen++;
    }
    // Taruh kursor tepat setelah digit yang baru diketik, bukan setelah titik ribuan.
    while (offset > 0 && digitsAfterCursor > 0 && !_isDigit(formatted.codeUnitAt(offset - 1))) {
      offset--;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  static bool _isDigit(int codeUnit) => codeUnit >= 48 && codeUnit <= 57;
}
