import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  
  static const _keyUsername = 'auth_username';
  static const _keyPassword = 'auth_password';
  static const _keyIsLoggedIn = 'auth_is_logged_in';

  Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: _keyUsername, value: username);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyIsLoggedIn, value: 'true');
  }

  Future<Map<String, String?>> getCredentials() async {
    final username = await _storage.read(key: _keyUsername);
    final password = await _storage.read(key: _keyPassword);
    return {'username': username, 'password': password};
  }

  Future<bool> isLoggedIn() async {
    final loggedIn = await _storage.read(key: _keyIsLoggedIn);
    return loggedIn == 'true';
  }

  Future<void> logout() async {
    // Solo borramos el estado de sesión y tal vez la contraseña, pero conservamos el usuario 
    // para prellenar el campo de login si se desea. En máxima seguridad, se borra todo.
    // Aquí borraremos solo el flag de logueado para obligarlo a poner la clave de nuevo.
    // Pero la consigna dice "generar el logout", vamos a borrar el estado.
    await _storage.delete(key: _keyIsLoggedIn);
    // Para mayor seguridad podemos borrar la contraseña.
    // await _storage.delete(key: _keyPassword);
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
