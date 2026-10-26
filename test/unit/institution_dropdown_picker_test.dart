import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hitung/core/constants/institution_presets.dart';
import 'package:hitung/shared/widgets/institution_dropdown_picker.dart';

void main() {
  Widget buildTestableWidget({
    required String? selectedCode,
    required ValueChanged<InstitutionPreset> onSelected,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: InstitutionDropdownPicker(
              label: 'Pilih Bank / Dompet Digital / Tunai',
              selectedCode: selectedCode,
              onSelected: onSelected,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('InstitutionDropdownPicker menampilkan institusi terpilih dan label', (tester) async {
    InstitutionPreset? selected = InstitutionPresets.getByCode('BCA');

    await tester.pumpWidget(buildTestableWidget(
      selectedCode: selected.code,
      onSelected: (p) => selected = p,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Pilih Bank / Dompet Digital / Tunai'), findsOneWidget);
    expect(find.text('BCA'), findsWidgets);
  });

  testWidgets('Mengetuk dropdown membuka menu anchored dengan list bank & e-wallet terkategorisasi', (tester) async {
    InstitutionPreset? selected = InstitutionPresets.getByCode('BCA');

    await tester.pumpWidget(buildTestableWidget(
      selectedCode: selected.code,
      onSelected: (p) => selected = p,
    ));
    await tester.pumpAndSettle();

    // Tap the dropdown trigger
    await tester.tap(find.text('Pilih Bank / Dompet Digital / Tunai'));
    await tester.pumpAndSettle();

    // Verify category header for BANK and items
    expect(find.text('BANK (Rekening)'), findsOneWidget);
    expect(find.text('Bank Jago'), findsOneWidget);
    expect(find.text('SeaBank'), findsWidgets);

    // Scroll down to verify DOMPET DIGITAL section
    await tester.scrollUntilVisible(
      find.text('DOMPET DIGITAL (E-Wallet)'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('DOMPET DIGITAL (E-Wallet)'), findsOneWidget);
    expect(find.text('GoPay'), findsWidgets);
  });

  testWidgets('Memilih institusi dari dropdown memicu callback onSelected dan menutup menu', (tester) async {
    InstitutionPreset? selected = InstitutionPresets.getByCode('BCA');

    await tester.pumpWidget(buildTestableWidget(
      selectedCode: selected.code,
      onSelected: (p) => selected = p,
    ));
    await tester.pumpAndSettle();

    // Tap to open
    await tester.tap(find.text('Pilih Bank / Dompet Digital / Tunai'));
    await tester.pumpAndSettle();

    // Select Bank Jago (visible in the initial list)
    await tester.tap(find.text('Bank Jago'));
    await tester.pumpAndSettle();

    expect(selected!.code, 'JAGO');
    // Dropdown overlay should be closed
    expect(find.text('PILIH BANK ATAU E-WALLET'), findsNothing);
  });
}
