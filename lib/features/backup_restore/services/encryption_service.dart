import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Enkripsi file cadangan berbasis kata sandi, 100% offline (Feature 5).
///
/// Format V2 (dipakai untuk file baru):
/// - Kunci: PBKDF2-HMAC-SHA256 ([defaultIterations] iterasi) menghasilkan 64 byte,
///   dipecah menjadi kunci enkripsi (32 byte) dan kunci MAC (32 byte).
/// - Enkripsi: stream cipher mode counter dengan keystream HMAC-SHA256(kunciEnc, iv||counter).
/// - Integritas: HMAC-SHA256(kunciMac, format||salt||iv||iterasi||ciphertext), diverifikasi
///   (waktu-konstan) SEBELUM dekripsi. Salah kata sandi atau file diubah -> ditolak.
///
/// Format V1 (lama) tetap bisa didekripsi agar file lama tidak hilang.
///
/// Kata sandi dipakai persis seperti diketik (tidak di-trim) di enkripsi maupun dekripsi.
class EncryptionService {
  static const String formatV1 = 'HITUNG_ENCRYPTED_V1';
  static const String formatV2 = 'HITUNG_ENCRYPTED_V2';
  static const String formatIdentifier = formatV2;
  static const int defaultIterations = 100000;
  static const int _v1Iterations = 10000;
  static const int _saltLength = 16;

  /// Memeriksa apakah teks merupakan file cadangan terenkripsi HITUNG (V1/V2).
  static bool isEncrypted(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> &&
          (decoded['format'] == formatV1 || decoded['format'] == formatV2);
    } catch (_) {
      return false;
    }
  }

  /// Versi async yang berjalan di isolate terpisah agar UI tidak macet saat derivasi kunci.
  static Future<String> encryptAsync(String plaintext, String password) =>
      Isolate.run(() => encrypt(plaintext, password));

  static Future<String> decryptAsync(String encryptedJson, String password) =>
      Isolate.run(() => decrypt(encryptedJson, password));

  static String encrypt(String plaintext, String password, {int iterations = defaultIterations}) {
    if (password.isEmpty) throw ArgumentError('Kata sandi tidak boleh kosong.');

    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final iv = List<int>.generate(16, (_) => random.nextInt(256));

    final keys = _pbkdf2(utf8.encode(password), salt, iterations, 64);
    final encKey = keys.sublist(0, 32);
    final macKey = keys.sublist(32, 64);

    final ciphertext = _processStream(utf8.encode(plaintext), encKey, iv);
    final mac = _mac(macKey, salt, iv, iterations, ciphertext);

    return const JsonEncoder.withIndent('  ').convert({
      'format': formatV2,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': iterations,
      'salt': _toHex(salt),
      'iv': _toHex(iv),
      'ciphertext': base64Encode(ciphertext),
      'mac': _toHex(mac),
    });
  }

  static String decrypt(String encryptedJson, String password) {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('File bukan format cadangan terenkripsi yang valid.');
    }

    try {
      switch (envelope['format']) {
        case formatV2:
          return _decryptV2(envelope, password);
        case formatV1:
          return _decryptV1(envelope, password);
        default:
          throw const FormatException('Format file terenkripsi tidak dikenali.');
      }
    } on FormatException {
      rethrow;
    } catch (_) {
      // Field hilang / tipe salah / base64 rusak.
      throw const FormatException('File cadangan terenkripsi rusak.');
    }
  }

  static String _decryptV2(Map<String, dynamic> env, String password) {
    final iterations = env['iterations'] as int;
    if (iterations < 1000 || iterations > 10000000) {
      throw const FormatException('File cadangan terenkripsi rusak.');
    }
    final salt = _fromHex(env['salt'] as String);
    final iv = _fromHex(env['iv'] as String);
    final ciphertext = base64Decode(env['ciphertext'] as String);
    final expectedMac = _fromHex(env['mac'] as String);

    final keys = _pbkdf2(utf8.encode(password), salt, iterations, 64);
    final actualMac = _mac(keys.sublist(32, 64), salt, iv, iterations, ciphertext);
    if (!_constantTimeEquals(actualMac, expectedMac)) {
      throw const FormatException('Kata sandi salah atau data cadangan rusak.');
    }
    final plain = _processStream(ciphertext, keys.sublist(0, 32), iv);
    return utf8.decode(plain);
  }

  static String _decryptV1(Map<String, dynamic> env, String password) {
    final salt = _fromHex(env['salt'] as String);
    final iv = _fromHex(env['iv'] as String);
    final ciphertext = base64Decode(env['ciphertext'] as String);
    final expectedChecksum = env['checksum'] as String;

    final key = _pbkdf2(utf8.encode(password), salt, _v1Iterations, 32);
    final plain = _processStream(ciphertext, key, iv);
    if (sha256.convert(plain).toString() != expectedChecksum) {
      throw const FormatException('Kata sandi salah atau data cadangan rusak.');
    }
    try {
      return utf8.decode(plain);
    } catch (_) {
      throw const FormatException('Kata sandi salah.');
    }
  }

  /// PBKDF2-HMAC-SHA256 standar (RFC 8018) dengan panjang keluaran [length] byte.
  static List<int> _pbkdf2(List<int> password, List<int> salt, int iterations, int length) {
    final hmac = Hmac(sha256, password);
    final out = <int>[];
    for (var blockIndex = 1; out.length < length; blockIndex++) {
      var u = hmac.convert([
        ...salt,
        (blockIndex >> 24) & 0xFF,
        (blockIndex >> 16) & 0xFF,
        (blockIndex >> 8) & 0xFF,
        blockIndex & 0xFF,
      ]).bytes;
      final t = List<int>.from(u);
      for (var i = 1; i < iterations; i++) {
        u = hmac.convert(u).bytes;
        for (var j = 0; j < t.length; j++) {
          t[j] ^= u[j];
        }
      }
      out.addAll(t);
    }
    return out.sublist(0, length);
  }

  static List<int> _mac(List<int> macKey, List<int> salt, List<int> iv, int iterations, List<int> ciphertext) {
    final header = utf8.encode('$formatV2|$iterations|');
    return Hmac(sha256, macKey).convert([...header, ...salt, ...iv, ...ciphertext]).bytes;
  }

  /// Keystream HMAC-SHA256(key, iv||counter), di-XOR dengan input.
  static Uint8List _processStream(List<int> input, List<int> key, List<int> iv) {
    final output = Uint8List(input.length);
    final hmac = Hmac(sha256, key);
    var counter = 0;
    for (var i = 0; i < input.length; i += 32) {
      final block = hmac.convert([
        ...iv,
        (counter >> 24) & 0xFF,
        (counter >> 16) & 0xFF,
        (counter >> 8) & 0xFF,
        counter & 0xFF,
      ]).bytes;
      counter++;
      final chunk = min(32, input.length - i);
      for (var j = 0; j < chunk; j++) {
        output[i + j] = input[i + j] ^ block[j];
      }
    }
    return output;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  static String _toHex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _fromHex(String hex) {
    if (hex.length.isOdd) throw const FormatException('File cadangan terenkripsi rusak.');
    return [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
  }
}
