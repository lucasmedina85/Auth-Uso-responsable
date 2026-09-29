import 'database_log_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class AuthService {
  static const _storage = FlutterSecureStorage();
  
  static const _keyUserEmail = 'auth_registered_email';
  static const _keyUserPasswordHash = 'auth_registered_pass_hash';
  static const _keyUserName = 'auth_registered_name';
  static const _keyIsLoggedIn = 'auth_is_logged_in';

  static String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static Future<void> register(String email, String password, String name) async {
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserPasswordHash, value: _hashPassword(password));
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyIsLoggedIn, value: 'true');
    await DatabaseLogService().logEvent('USER_REGISTER', 'Nuevo usuario registrado: $email', 'SUCCESS');
  }

  static Future<bool> login(String email, String password) async {
    final registeredEmail = await _storage.read(key: _keyUserEmail);
    final registeredHash = await _storage.read(key: _keyUserPasswordHash);

    if (registeredEmail == email && registeredHash == _hashPassword(password)) {
      await _storage.write(key: _keyIsLoggedIn, value: 'true');
      await DatabaseLogService().logEvent('USER_LOGIN', 'Ingreso exitoso para $email', 'SUCCESS');
      return true;
    }
    await DatabaseLogService().logEvent('USER_LOGIN', 'Intento fallido para $email', 'FAILED');
    return false;
  }

  static Future<bool> isLoggedIn() async {
    final loggedIn = await _storage.read(key: _keyIsLoggedIn);
    return loggedIn == 'true';
  }

  static Future<void> logout() async {
    await _storage.delete(key: _keyIsLoggedIn);
  }

  static Future<Map<String, String?>> getUserData() async {
    final email = await _storage.read(key: _keyUserEmail);
    final name = await _storage.read(key: _keyUserName);
    return {'email': email, 'name': name};
  }
}
