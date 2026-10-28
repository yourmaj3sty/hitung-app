import 'package:universal_io/io.dart';
import 'package:flutter/services.dart';

/// Mengaktifkan FLAG_SECURE di Android: isi layar tidak tampil di app switcher
/// (Recents) dan tidak bisa di-screenshot/direkam. Overlay Flutter saja tidak andal
/// karena Android sering mengambil cuplikan Recents sebelum frame overlay sempat digambar.
class PrivacyGuard {
  static const MethodChannel _channel = MethodChannel('id.hitung.app/privacy');

  static Future<void> setSecure(bool enabled) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'enabled': enabled});
    } catch (_) {
      // Tidak fatal: overlay privasi Flutter tetap berjalan sebagai cadangan.
    }
  }
}
