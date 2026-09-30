import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:developer';
import '../core/network/dio_client.dart';

class SessionService {
  static const _storage = FlutterSecureStorage();
  
  static const _keyAccessToken = 'auth_access_token';
  static const _keyRefreshToken = 'auth_refresh_token';

  static const _legacyKeys = [
    'auth_username',
    'auth_password',
    'auth_registered_email',
    'auth_registered_pass_hash',
    'auth_registered_name',
    'auth_is_logged_in'
  ];

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
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  // Auth Operations calling backend directly bypassing interceptor loop for login
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
}
