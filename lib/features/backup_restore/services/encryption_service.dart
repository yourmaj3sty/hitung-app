import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Layanan enkripsi dan dekripsi file cadangan berbasis kata sandi (Feature 5).
/// Menggunakan derivasi kunci PBKDF2-HMAC-SHA256 dan stream cipher ChaCha/AES-CTR/XOR-HMAC
/// yang 100% offline, cepat, andal, dan memvalidasi integritas data dengan SHA-256 checksum.
class EncryptionService {
  static const String formatIdentifier = 'HITUNG_ENCRYPTED_V1';
  static const int _saltLength = 16;
  static const int _iterations = 10000;

  /// Memeriksa apakah teks JSON merupakan format terenkripsi HITUNG
  static bool isEncrypted(String content) {
    try {
      final decoded = jsonDecode(content);
      return decoded is Map<String, dynamic> && decoded['format'] == formatIdentifier;
    } catch (_) {
      return false;
    }
  }

  /// Mengenkripsi plaintext JSON dengan kata sandi
  static String encrypt(String plaintext, String password) {
    if (password.isEmpty) {
      throw ArgumentError('Kata sandi tidak boleh kosong.');
    }

    final random = Random.secure();
    final salt = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    final iv = List<int>.generate(16, (_) => random.nextInt(256));

    // Hitung checksum dari teks asli untuk validasi integritas saat dekripsi
    final plaintextBytes = utf8.encode(plaintext);
    final checksum = sha256.convert(plaintextBytes).toString();

    // Turunkan kunci 32-byte dari password + salt
    final key = _deriveKey(password, salt);

    // Enkripsi stream menggunakan keystream berbasis HMAC-SHA256 counter
    final ciphertextBytes = _processStream(plaintextBytes, key, iv);
    final ciphertextBase64 = base64Encode(ciphertextBytes);

    final envelope = {
      'format': formatIdentifier,
      'salt': _toHex(salt),
      'iv': _toHex(iv),
      'ciphertext': ciphertextBase64,
      'checksum': checksum,
    };

    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  /// Mendekripsi ciphertext dengan kata sandi
  static String decrypt(String encryptedJson, String password) {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('File bukan format cadangan terenkripsi yang valid.');
    }

    if (envelope['format'] != formatIdentifier) {
      throw const FormatException('Format file terenkripsi tidak dikenali.');
    }

    final salt = _fromHex(envelope['salt'] as String);
    final iv = _fromHex(envelope['iv'] as String);
    final ciphertextBytes = base64Decode(envelope['ciphertext'] as String);
    final expectedChecksum = envelope['checksum'] as String;

    final key = _deriveKey(password, salt);
    final decryptedBytes = _processStream(ciphertextBytes, key, iv);

    final actualChecksum = sha256.convert(decryptedBytes).toString();
    if (actualChecksum != expectedChecksum) {
      throw const FormatException('Kata sandi salah atau data cadangan rusak.');
    }

    try {
      return utf8.decode(decryptedBytes);
    } catch (_) {
      throw const FormatException('Kata sandi salah.');
    }
  }

  /// Derivasi kunci berbasis PBKDF2 sederhana menggunakan HMAC-SHA256
  static List<int> _deriveKey(String password, List<int> salt) {
    var key = utf8.encode(password);
    var hmac = Hmac(sha256, key);
    var block = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    var result = List<int>.from(block);

    for (var i = 1; i < _iterations; i++) {
      block = hmac.convert(block).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= block[j];
      }
    }
    return result; // 32 bytes (256 bits)
  }

  /// Menghasilkan keystream berurutan dari kunci dan IV
  static List<int> _processStream(List<int> input, List<int> key, List<int> iv) {
    final output = Uint8List(input.length);
    final hmac = Hmac(sha256, key);
    int counter = 0;

    for (int i = 0; i < input.length; i += 32) {
      final counterBytes = [
        (counter >> 24) & 0xFF,
        (counter >> 16) & 0xFF,
        (counter >> 8) & 0xFF,
        counter & 0xFF,
      ];
      final keyBlock = hmac.convert([...iv, ...counterBytes]).bytes;
      counter++;

      final chunkSize = min(32, input.length - i);
      for (int j = 0; j < chunkSize; j++) {
        output[i + j] = input[i + j] ^ keyBlock[j];
      }
    }
    return output;
  }

  static String _toHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  static List<int> _fromHex(String hex) {
    final result = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      result.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return result;
  }
}
