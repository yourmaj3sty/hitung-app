import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('Format positive amount without decimal ,00', () {
      final formatted = CurrencyFormatter.format(150000);
      expect(formatted, 'Rp 150.000');
    });

    test('Format zero amount', () {
      final formatted = CurrencyFormatter.format(0);
      expect(formatted, 'Rp 0');
    });

    test('Format large amount up to 12 digits', () {
      final formatted = CurrencyFormatter.format(999999999999);
      expect(formatted, 'Rp 999.999.999.999');
    });

    test('Format with sign', () {
      expect(CurrencyFormatter.format(50000, showSign: true), '+Rp 50.000');
      expect(CurrencyFormatter.format(-50000, showSign: true), '-Rp 50.000');
    });

    test('Format without currency symbol', () {
      expect(CurrencyFormatter.format(250000, includeSymbol: false), '250.000');
    });

    test('Parse string back to integer Rupiah', () {
      expect(CurrencyFormatter.parse('Rp 150.000'), 150000);
      expect(CurrencyFormatter.parse('1.000.000'), 1000000);
      expect(CurrencyFormatter.parse(''), 0);
      expect(CurrencyFormatter.parse('abc'), 0);
    });

    test('PRD Rule 3: Tabular figures fontFeature is defined', () {
      expect(CurrencyFormatter.tabularFigures, contains(const FontFeature.tabularFigures()));
    });
  });
}
