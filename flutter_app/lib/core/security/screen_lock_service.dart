import 'package:local_auth/local_auth.dart';

/// CU-0021: Validación de Bloqueo de Pantalla
/// Verifies if device has an active PIN, Pattern, Passcode or Biometrics configured.
class ScreenLockService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device screen lock or biometrics are properly configured
  Future<bool> isScreenLockConfigured() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  /// Get detailed description of available security hardware
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
}
