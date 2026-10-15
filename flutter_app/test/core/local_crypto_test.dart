import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/core/security/local_crypto_helper.dart';

void main() {
  group('LocalCryptoHelper Offline Tests', () {
    test('PBKDF2 hashes password deterministically given the same salt', () {
      const password = 'Demo12345!';
      final salt = LocalCryptoHelper.generateSalt(16);

      final hash1 = LocalCryptoHelper.hashPassword(password, salt, iterations: 1000);
      final hash2 = LocalCryptoHelper.hashPassword(password, salt, iterations: 1000);

      expect(hash1, equals(hash2));
      expect(hash1.length, equals(64)); // 32 bytes in hex = 64 characters
    });

    test('PBKDF2 produces different hashes for different salts', () {
      const password = 'Demo12345!';
      final salt1 = LocalCryptoHelper.generateSalt(16);
      final salt2 = LocalCryptoHelper.generateSalt(16);

      final hash1 = LocalCryptoHelper.hashPassword(password, salt1, iterations: 1000);
      final hash2 = LocalCryptoHelper.hashPassword(password, salt2, iterations: 1000);

      expect(hash1, isNot(equals(hash2)));
    });

    test('verifyPassword validates correct password and rejects wrong password', () {
      const password = 'Demo12345!';
      final salt = LocalCryptoHelper.generateSalt(16);
      final hash = LocalCryptoHelper.hashPassword(password, salt, iterations: 1000);

      final isValid = LocalCryptoHelper.verifyPassword(password, salt, hash, iterations: 1000);
      expect(isValid, isTrue);

      final isWrong = LocalCryptoHelper.verifyPassword('WrongPassword!', salt, hash, iterations: 1000);
      expect(isWrong, isFalse);
    });

    test('sha256Hex computes accurate 64-char hex digest', () {
      final digest = LocalCryptoHelper.sha256Hex('hello sip offline');
      expect(digest.length, equals(64));
    });
  });
}
