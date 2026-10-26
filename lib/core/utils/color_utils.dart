import 'package:flutter/painting.dart';

/// Parsing warna hex yang aman. Nilai rusak (misalnya dari file cadangan)
/// tidak boleh membuat aplikasi crash, jadi selalu ada warna cadangan.
class ColorUtils {
  static const Color fallback = Color(0xFF64748B); // Slate
  static final RegExp _hexPattern = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');

  static bool isValidHex(String? hex) => hex != null && _hexPattern.hasMatch(hex.trim());

  /// Menerima '#RRGGBB', 'RRGGBB', '#AARRGGBB', atau 'AARRGGBB'.
  static Color fromHex(String? hex, {Color fallback = fallback}) {
    if (!isValidHex(hex)) return fallback;
    var value = hex!.trim().replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    return Color(int.parse(value, radix: 16));
  }
}
