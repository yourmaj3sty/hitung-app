import 'package:flutter/material.dart';
import '../utils/color_utils.dart';

enum InstitutionCategory {
  bank,
  eWallet,
  cash,
}

class InstitutionPreset {
  final String code;
  final String name;
  final String shortLabel;
  final String colorHex;
  final InstitutionCategory category;
  final String defaultIcon;

  const InstitutionPreset({
    required this.code,
    required this.name,
    required this.shortLabel,
    required this.colorHex,
    required this.category,
    this.defaultIcon = 'landmark',
  });

  Color get color => ColorUtils.fromHex(colorHex);
}

class InstitutionPresets {
  // Bank Digital & Konvensional (BANK)
  static const List<InstitutionPreset> banks = [
    InstitutionPreset(
      code: 'JAGO',
      name: 'Bank Jago',
      shortLabel: 'Jago',
      colorHex: '#FF6B00',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'SEABANK',
      name: 'SeaBank',
      shortLabel: 'SeaBank',
      colorHex: '#FF5722',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'BLU',
      name: 'blu by BCA',
      shortLabel: 'blu',
      colorHex: '#00A2E9',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'BCA',
      name: 'BCA',
      shortLabel: 'BCA',
      colorHex: '#0060AF',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'MANDIRI',
      name: 'Mandiri / Livin\'',
      shortLabel: 'Mandiri',
      colorHex: '#003D79',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'BNI',
      name: 'BNI / wondr',
      shortLabel: 'BNI',
      colorHex: '#F15A23',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'BRI',
      name: 'BRI / BRImo',
      shortLabel: 'BRI',
      colorHex: '#00529C',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'BSI',
      name: 'BSI',
      shortLabel: 'BSI',
      colorHex: '#00A39D',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
    InstitutionPreset(
      code: 'OTHER_BANK',
      name: 'Bank Lainnya',
      shortLabel: 'Bank',
      colorHex: '#475569',
      category: InstitutionCategory.bank,
      defaultIcon: 'landmark',
    ),
  ];

  // Dompet Digital (E_WALLET)
  static const List<InstitutionPreset> eWallets = [
    InstitutionPreset(
      code: 'GOPAY',
      name: 'GoPay',
      shortLabel: 'GoPay',
      colorHex: '#00AED6',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
    InstitutionPreset(
      code: 'OVO',
      name: 'OVO',
      shortLabel: 'OVO',
      colorHex: '#4C3494',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
    InstitutionPreset(
      code: 'DANA',
      name: 'DANA',
      shortLabel: 'DANA',
      colorHex: '#118EEA',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
    InstitutionPreset(
      code: 'SHOPEEPAY',
      name: 'ShopeePay',
      shortLabel: 'ShopeePay',
      colorHex: '#EE4D2D',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
    InstitutionPreset(
      code: 'LINKAJA',
      name: 'LinkAja',
      shortLabel: 'LinkAja',
      colorHex: '#E31E24',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
    InstitutionPreset(
      code: 'OTHER_WALLET',
      name: 'E-Wallet Lainnya',
      shortLabel: 'E-Wallet',
      colorHex: '#64748B',
      category: InstitutionCategory.eWallet,
      defaultIcon: 'smartphone',
    ),
  ];

  // Tunai (CASH)
  static const List<InstitutionPreset> cash = [
    InstitutionPreset(
      code: 'TUNAI',
      name: 'Uang Tunai / Cash',
      shortLabel: 'Tunai',
      colorHex: '#00AA13',
      category: InstitutionCategory.cash,
      defaultIcon: 'banknote',
    ),
  ];

  // All combined presets
  static List<InstitutionPreset> get all => [
        ...banks,
        ...eWallets,
        ...cash,
      ];

  // Default fallback preset
  static const InstitutionPreset defaultPreset = InstitutionPreset(
    code: 'CUSTOM',
    name: 'Kustom',
    shortLabel: 'Kustom',
    colorHex: '#00AED6',
    category: InstitutionCategory.eWallet,
    defaultIcon: 'wallet',
  );

  static InstitutionPreset getByCode(String? code) {
    if (code == null || code.isEmpty || code == 'CUSTOM') {
      return defaultPreset;
    }
    for (final p in all) {
      if (p.code.toUpperCase() == code.toUpperCase()) {
        return p;
      }
    }
    return defaultPreset;
  }
}
