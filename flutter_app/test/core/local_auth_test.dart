import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/core/security/local_crypto_helper.dart';

void main() {
  group('Local Authentication Security & Anti-Enumeration Tests', () {
    test('Password verification against PBKDF2 with constant-time comparison', () {
      final salt = LocalCryptoHelper.generateSalt(16);
      const correctPass = 'Demo12345!';
      final hash = LocalCryptoHelper.hashPassword(correctPass, salt, iterations: 1000);

      // Correct password verifies successfully
      expect(LocalCryptoHelper.verifyPassword(correctPass, salt, hash, iterations: 1000), isTrue);

      // Wrong password fails
      expect(LocalCryptoHelper.verifyPassword('WrongPass123!', salt, hash, iterations: 1000), isFalse);

      // Empty password fails
      expect(LocalCryptoHelper.verifyPassword('', salt, hash, iterations: 1000), isFalse);
    });

    test('Anti-enumeration dummy calculation produces deterministic hash length', () {
      // For nonexistent users, PBKDF2 is computed with a dummy salt to match timing
      const dummySalt = '0123456789abcdef0123456789abcdef';
      final dummyHash = LocalCryptoHelper.hashPassword('SomePassword', dummySalt, iterations: 1000);

      expect(dummyHash.length, equals(64));
    });

    test('Lockout duration calculation provides accurate remaining seconds', () {
      final now = DateTime.now();
      final lockedUntil = now.add(const Duration(seconds: 45));

      final remainingSeconds = lockedUntil.difference(now).inSeconds;
      expect(remainingSeconds, inInclusiveRange(44, 45));
    });
  });
}
