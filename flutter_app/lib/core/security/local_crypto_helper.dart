import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Utilidades criptográficas 100% offline y en Dart puro para el modo LOCAL.
class LocalCryptoHelper {
  /// Genera una sal criptográfica segura de [length] bytes en formato hexadecimal.
  static String generateSalt([int length = 16]) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytesToHex(bytes);
  }

  /// PBKDF2 con HMAC-SHA256 (RFC 2898) en Dart puro.
  static String hashPassword(String password, String saltHex, {int iterations = 10000, int keyLength = 32}) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = hexToBytes(saltHex);
    final hmac = Hmac(sha256, passwordBytes);

    final numBlocks = (keyLength + 31) ~/ 32;
    final derivedKey = Uint8List(keyLength);
    int offset = 0;

    for (int block = 1; block <= numBlocks; block++) {
      final blockBytes = Uint8List(saltBytes.length + 4);
      blockBytes.setRange(0, saltBytes.length, saltBytes);
      ByteData.view(blockBytes.buffer).setUint32(saltBytes.length, block, Endian.big);

      Uint8List u = Uint8List.fromList(hmac.convert(blockBytes).bytes);
      Uint8List blockXor = Uint8List.fromList(u);

      for (int iter = 1; iter < iterations; iter++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < blockXor.length; k++) {
          blockXor[k] ^= u[k];
        }
      }

      final copyLen = min(32, keyLength - offset);
      derivedKey.setRange(offset, offset + copyLen, blockXor.sublist(0, copyLen));
      offset += copyLen;
    }

    return bytesToHex(derivedKey);
  }

  /// Verificación de contraseña en tiempo constante para mitigar timing attacks.
  static bool verifyPassword(String password, String saltHex, String expectedHashHex, {int iterations = 10000}) {
    final calculated = hashPassword(password, saltHex, iterations: iterations);
    if (calculated.length != expectedHashHex.length) return false;
    int result = 0;
    for (int i = 0; i < calculated.length; i++) {
      result |= calculated.codeUnitAt(i) ^ expectedHashHex.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Calcula el hash SHA-256 de un texto plano.
  static String sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Calcula HMAC-SHA256 de un texto plano con una clave secreta.
  static String hmacSha256Hex(String secret, String input) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(input)).toString();
  }

  static String bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List hexToBytes(String hex) {
    final clean = hex.replaceAll(' ', '');
    final bytes = Uint8List(clean.length ~/ 2);
    for (int i = 0; i < clean.length; i += 2) {
      bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
    }
    return bytes;
  }
}
