import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/database/app_database.dart';
import 'package:hitung/shared/widgets/categorized_wallet_picker.dart';

void main() {
  final sampleWallets = [
    Wallet(
      id: 'w-bca',
      name: 'BCA Utama',
      iconName: 'landmark',
      colorHex: '#0060AF',
      initialBalance: 2500000,
      currentBalance: 2500000,
      createdAt: DateTime.now(),
      isArchived: false,
      walletType: 'BANK',
      institutionCode: 'BCA',
    ),
    Wallet(
      id: 'w-gopay',
      name: 'GoPay Jajan',
      iconName: 'smartphone',
      colorHex: '#00AED6',
      initialBalance: 350000,
      currentBalance: 350000,
      createdAt: DateTime.now(),
      isArchived: false,
      walletType: 'E_WALLET',
      institutionCode: 'GOPAY',
    ),
    Wallet(
      id: 'w-savings',
      name: 'Kantong Liburan',
      iconName: 'sparkles',
      colorHex: '#7C3AED',
      initialBalance: 1200000,
      currentBalance: 1200000,
      createdAt: DateTime.now(),
      isArchived: false,
      walletType: 'SAVINGS',
      institutionCode: 'GOPAY',
      targetAmount: 5000000,
    ),
    Wallet(
      id: 'w-cash',
      name: 'Dompet Saku',
      iconName: 'banknote',
      colorHex: '#00AA13',
      initialBalance: 150000,
      currentBalance: 150000,
      createdAt: DateTime.now(),
      isArchived: false,
      walletType: 'CASH',
      institutionCode: 'TUNAI',
    ),
  ];

  Widget buildTestableWidget({
    required String? selectedWalletId,
    required ValueChanged<String?> onChanged,
    bool isCompact = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CategorizedWalletDropdown(
              label: 'Pilih Dompet / Sumber Dana',
              selectedWalletId: selectedWalletId,
              wallets: sampleWallets,
              isCompact: isCompact,
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('CategorizedWalletPicker menampilkan akun terpilih dan label', (tester) async {
    String? selected = 'w-bca';

    await tester.pumpWidget(buildTestableWidget(
      selectedWalletId: selected,
      onChanged: (id) => selected = id,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Dompet / Sumber Dana'), findsOneWidget);
    expect(find.text('BCA Utama'), findsOneWidget);
    expect(find.text('BCA'), findsOneWidget);
    expect(find.textContaining('2.500.000'), findsOneWidget);
  });

  testWidgets('Mengetuk dropdown membuka menu anchored dengan kategori lengkap', (tester) async {
    String? selected = 'w-bca';

    await tester.pumpWidget(buildTestableWidget(
      selectedWalletId: selected,
      onChanged: (id) => selected = id,
    ));
    await tester.pumpAndSettle();

    // Tap dropdown box to open menu
    await tester.tap(find.text('BCA Utama'));
    await tester.pumpAndSettle();

    // Verify category headers in the dropdown menu
    expect(find.text('BANK (Rekening)'), findsOneWidget);
    expect(find.text('DOMPET DIGITAL (E-Wallet)'), findsOneWidget);
    expect(find.text('KANTONG TABUNGAN (✦)'), findsOneWidget);

    // Verify wallets visible inside dropdown
    expect(find.text('GoPay Jajan'), findsOneWidget);
    expect(find.text('Kantong Liburan'), findsOneWidget);

    // Scroll to check bottom cash section
    await tester.scrollUntilVisible(
      find.text('Dompet Saku'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Dompet Saku'), findsOneWidget);
  });

  testWidgets('Memilih item dompet memicu onChanged dan menutup menu dropdown', (tester) async {
    String? selected = 'w-bca';

    await tester.pumpWidget(buildTestableWidget(
      selectedWalletId: selected,
      onChanged: (id) => selected = id,
    ));
    await tester.pumpAndSettle();

    // Tap to open
    await tester.tap(find.text('BCA Utama'));
    await tester.pumpAndSettle();

    // Tap on 'GoPay Jajan' inside dropdown
    await tester.tap(find.text('GoPay Jajan'));
    await tester.pumpAndSettle();

    // Verify onChanged fired
    expect(selected, 'w-gopay');

    // Verify dropdown overlay closed
    expect(find.text('DOMPET DIGITAL (E-Wallet)'), findsNothing);
  });
}
