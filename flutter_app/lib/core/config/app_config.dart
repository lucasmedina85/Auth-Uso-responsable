class AppConfig {
  /// Modo de ejecución: 'local' (100% offline en el celular) o 'remote' (con backend Spring Boot).
  /// Por defecto: 'local'.
  static const String backendMode = String.fromEnvironment('BACKEND_MODE', defaultValue: 'local');

  static bool get isLocal => backendMode == 'local';
  static bool get isRemote => backendMode == 'remote';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080'),
  );
}
