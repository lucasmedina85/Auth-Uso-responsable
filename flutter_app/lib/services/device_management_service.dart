import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../core/security/screen_lock_service.dart';
import '../models/device_model.dart';
import '../models/security_score_model.dart';
import 'notification_service.dart';
import 'session_service.dart';

class DeviceManagementService {
  static final DeviceManagementService _instance = DeviceManagementService._internal();
  factory DeviceManagementService() => _instance;
  DeviceManagementService._internal();

  final Dio _dio = DioClient().dio;
  final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();

  Future<List<DeviceModel>> getDevices() async {
    try {
      final response = await _dio.get('/devices');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => DeviceModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  Future<DeviceModel?> registerCurrentDevice() async {
    String deviceName = 'Dispositivo móvil';
    String os = Platform.operatingSystem;
    String manufacturer = 'Desconocido';

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfoPlugin.androidInfo;
        manufacturer = androidInfo.manufacturer;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
        os = 'Android ${androidInfo.version.release}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfoPlugin.iosInfo;
        manufacturer = 'Apple';
        deviceName = iosInfo.name;
        os = 'iOS ${iosInfo.systemVersion}';
      }
    } catch (_) {
      // Fallback a valores por defecto
    }

    final deviceId = await SessionService.getDeviceId();
    final response = await _dio.post('/devices/register', data: {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'manufacturer': manufacturer,
      'osVersion': os,
      'deviceType': 'MOBILE',
    });

    if (response.statusCode == 200 && response.data != null) {
      return DeviceModel.fromJson(response.data as Map<String, dynamic>);
    }
    return null;
  }

  Future<void> approveDevice(String deviceId) async {
    await _dio.post('/devices/$deviceId/approve');
  }

  Future<void> revokeDevice(String deviceId) async {
    await _dio.post('/devices/$deviceId/revoke');
  }

  Future<List<DeviceAlertModel>> getAlerts() async {
    try {
      final response = await _dio.get('/devices/alerts');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => DeviceAlertModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } on DioException {
      return [];
    }
  }

  Future<void> checkAndNotifyAlerts() async {
    try {
      final alerts = await getAlerts();
      if (alerts.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final notified = prefs.getStringList('notified_device_alerts') ?? [];

      for (final alert in alerts) {
        if (!notified.contains(alert.id)) {
          await NotificationService().showNotification(
            'Alerta de Dispositivo',
            alert.message.isNotEmpty
                ? alert.message
                : 'Nuevo dispositivo pendiente de aprobación: ${alert.deviceName}',
          );
          notified.add(alert.id);
        }
      }

      await prefs.setStringList('notified_device_alerts', notified);
    } catch (_) {
      // Silenciar errores de sondeo en segundo plano
    }
  }

  Future<SecurityScoreModel?> getSecurityScore() async {
    try {
      final hasScreenLock = await ScreenLockService().isScreenLockConfigured();
      final hasBiometrics = await ScreenLockService().hasBiometrics();

      final response = await _dio.get(
        '/users/security-score',
        queryParameters: {
          'hasBiometrics': hasBiometrics,
          'hasScreenLock': hasScreenLock,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        return SecurityScoreModel.fromJson(response.data as Map<String, dynamic>);
      }
      return null;
    } on DioException {
      return null;
    }
  }
}
