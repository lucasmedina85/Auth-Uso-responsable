import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:developer';
import 'dart:math' show Random;
import '../core/network/dio_client.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();
  static final LocalAuthentication _localAuth = LocalAuthentication();
  
  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';
  static const _keyRememberSession = 'auth_remember_session';
  static const _keyDeviceInstanceId = 'auth_device_instance_id';

  static const _legacyKeys = [
    'auth_username',
    'auth_password',
    'auth_registered_email',
    'auth_registered_pass_hash',
    'auth_registered_name',
    'auth_is_logged_in'
  ];

  static Future<String> getDeviceId() async {
    String? id = await _storage.read(key: _keyDeviceInstanceId);
    if (id == null || id.isEmpty) {
      final random = Random.secure();
      final values = List<int>.generate(16, (i) => random.nextInt(256));
      values[6] = (values[6] & 0x0f) | 0x40; // RFC 4122 v4
      values[8] = (values[8] & 0x3f) | 0x80;
      final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      id = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
      await _storage.write(key: _keyDeviceInstanceId, value: id);
    }
    return id;
  }

  static Future<void> setRememberSession(bool remember) async {
    await _storage.write(key: _keyRememberSession, value: remember ? 'true' : 'false');
  }

  static Future<bool> isRememberSessionEnabled() async {
    final val = await _storage.read(key: _keyRememberSession);
    return val == 'true';
  }

  static Future<bool> unlockSessionWithBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        return false;
      }
      return await _localAuth.authenticate(
        localizedReason: 'Autenticate para reanudar tu sesión segura',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (e) {
      log('Error en autenticación biométrica: $e');
      return false;
    }
  }

  static Future<void> initializeAndCleanLegacy() async {
    for (String key in _legacyKeys) {
      if (await _storage.containsKey(key: key)) {
        log('Borrando residuo inseguro del storage: $key');
        await _storage.delete(key: key);
      }
    }
  }

  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _keyAccessToken, value: accessToken);
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  static Future<Map<String, String?>> getTokens() async {
    final access = await _storage.read(key: _keyAccessToken);
    final refresh = await _storage.read(key: _keyRefreshToken);
    return {'accessToken': access, 'refreshToken': refresh};
  }
  
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }

  static Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    await _storage.delete(key: _keyRememberSession);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  static Future<bool> login(String email, String password) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: DioClient.baseUrl));
      final response = await dio.post('/auth/login', data: {
        'email': email,
        'password': password
      });
      if (response.statusCode == 200) {
        await saveTokens(response.data['accessToken'], response.data['refreshToken']);
        return true;
      }
    } on DioException catch (e) {
      log('Login dio error: $e');
      rethrow;
    } catch (e) {
      log('Login error: $e');
    }
    return false;
  }

  static Future<bool> register(String email, String password, String name) async {
    try {
      final dio = Dio(BaseOptions(baseUrl: DioClient.baseUrl));
      final response = await dio.post('/auth/register', data: {
        'email': email,
        'password': password
      });
      return response.statusCode == 201;
    } catch (e) {
      log('Register error: $e');
    }
    return false;
  }

  static Future<void> logout() async {
    try {
      final dio = DioClient().dio;
      final tokens = await getTokens();
      await dio.post('/auth/logout', data: {
        'refreshToken': tokens['refreshToken']
      });
    } catch (e) {
      log('Logout error: $e');
    } finally {
      await clearTokens();
    }
  }

  // Fetch user status (e.g. REGISTERED, LOCALLY_VERIFIED)
  static Future<String?> fetchUserStatus() async {
    try {
      final dio = DioClient().dio;
      final response = await dio.get('/users/me');
      if (response.statusCode == 200) {
        return response.data['status']; // Backend returns UserDTO which has 'status'
      }
    } catch (e) {
      log('Fetch user status error: $e');
    }
    return null;
  }

  /// Realiza la reautenticación para operaciones sensibles (CU-0048).
  /// Solicita el reauth-token efímero al backend mediante POST /auth/reauth.
  /// La contraseña viaja en el cuerpo en memoria y se descarta inmediatamente.
  static Future<String?> requestReauthToken(String password) async {
    try {
      final dio = DioClient().dio;
      final response = await dio.post('/auth/reauth', data: {
        'password': password,
      });
      if (response.statusCode == 200 && response.data is Map) {
        return response.data['reauthToken']?.toString();
      }
      return null;
    } catch (e) {
      log('Error solicitando reauth-token: $e');
      rethrow;
    }
  }
}
