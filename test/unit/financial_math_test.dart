import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PRD Rule 2: Integer-Only Financial Math Tests', () {
    test('Calculations must only use integers and produce exact whole Rupiah amounts', () {
      const int initialWalletBalance = 5000000; // Rp 5.000.000
      const int expense1 = 45000;               // Rp 45.000
      const int expense2 = 1250000;             // Rp 1.250.000
      const int income = 2500000;               // Rp 2.500.000

      const int afterExpense = initialWalletBalance - expense1 - expense2;
      expect(afterExpense, 3705000);

      const int finalBalance = afterExpense + income;
      expect(finalBalance, 6205000);
      expect(finalBalance, isA<int>());
    });

    test('Transfer math is zero-sum across wallets', () {
      int sourceWallet = 1000000; // Rp 1.000.000
      int targetWallet = 250000;  // Rp 250.000
      const int transferAmount = 300000; // Rp 300.000

      final totalBefore = sourceWallet + targetWallet;

      // Transfer mutation
      sourceWallet -= transferAmount;
      targetWallet += transferAmount;

      final totalAfter = sourceWallet + targetWallet;

      expect(sourceWallet, 700000);
      expect(targetWallet, 550000);
      expect(totalBefore, totalAfter);
    });

    test('Budget percentage uses integer truncation/division without float drift', () {
      const int budget = 2000000;
      const int spent = 1590000;

      const int percentage = (spent * 100) ~/ budget;
      expect(percentage, 79); // < 80% (Green)

      const int spentOrange = 1600000;
      const int pctOrange = (spentOrange * 100) ~/ budget;
      expect(pctOrange, 80); // 80% (Orange)

      const int spentRed = 2000000;
      const int pctRed = (spentRed * 100) ~/ budget;
      expect(pctRed, 100); // 100% (Red)
    });

    test('Maximum 12-digit integer arithmetic limit', () {
      const int maxDigits = 999999999999; // Rp 999.999.999.999
      expect(maxDigits.toString().length, 12);
      expect(maxDigits, isA<int>());
    });
  });
}
