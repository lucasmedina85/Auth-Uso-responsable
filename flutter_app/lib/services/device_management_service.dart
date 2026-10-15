import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/app_config.dart';
import '../core/database/app_database.dart';
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
    if (AppConfig.isLocal) {
      final rows = await AppDatabase().getDevices();
      final currentDevId = await SessionService.getDeviceId();
      return rows.map((r) => DeviceModel(
        id: r['id'].toString(),
        deviceHash: r['device_id'].toString(),
        deviceName: r['device_name'].toString(),
        manufacturer: r['manufacturer'] as String?,
        osVersion: r['os_version'] as String?,
        deviceType: r['device_type'] as String? ?? 'MOBILE',
        status: r['status'] as String? ?? 'PENDING',
        isCurrent: r['device_id'] == currentDevId,
        firstSeenAt: DateTime.tryParse(r['created_at'].toString()),
        lastSeenAt: DateTime.tryParse(r['last_seen_at'].toString()),
        trustEvaluatedAt: r['status'] == 'TRUSTED' ? DateTime.tryParse(r['created_at'].toString()) : null,
      )).toList();
    }

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

    if (AppConfig.isLocal) {
      final row = await AppDatabase().registerDevice({
        'deviceId': deviceId,
        'deviceName': deviceName,
        'manufacturer': manufacturer,
        'osVersion': os,
        'deviceType': 'MOBILE',
      });
      return DeviceModel(
        id: row['id'].toString(),
        deviceHash: row['device_id'].toString(),
        deviceName: row['device_name'].toString(),
        manufacturer: row['manufacturer'] as String?,
        osVersion: row['os_version'] as String?,
        deviceType: row['device_type'] as String? ?? 'MOBILE',
        status: row['status'] as String? ?? 'TRUSTED',
        isCurrent: true,
        firstSeenAt: DateTime.tryParse(row['created_at'].toString()),
        lastSeenAt: DateTime.tryParse(row['last_seen_at'].toString()),
        trustEvaluatedAt: DateTime.now(),
      );
    }

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
    if (AppConfig.isLocal) {
      await AppDatabase().updateDeviceStatus(deviceId, 'TRUSTED');
      return;
    }
    await _dio.post('/devices/$deviceId/approve');
  }

  Future<void> revokeDevice(String deviceId) async {
    if (AppConfig.isLocal) {
      await AppDatabase().updateDeviceStatus(deviceId, 'REVOKED');
      return;
    }
    await _dio.post('/devices/$deviceId/revoke');
  }

  Future<List<DeviceAlertModel>> getAlerts() async {
    if (AppConfig.isLocal) {
      final devices = await AppDatabase().getDevices();
      final pending = devices.where((d) => d['status'] == 'PENDING').toList();
      return pending.map((d) => DeviceAlertModel(
        id: 'alert-${d['id']}',
        deviceName: d['device_name'].toString(),
        type: 'PENDING_APPROVAL',
        message: 'Dispositivo pendiente de aprobación: ${d['device_name']}',
        timestamp: DateTime.tryParse(d['created_at'].toString()),
      )).toList();
    }

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
    final hasScreenLock = await ScreenLockService().isScreenLockConfigured();
    final hasBiometrics = await ScreenLockService().hasBiometrics();

    if (AppConfig.isLocal) {
      final userStatus = await SessionService.fetchUserStatus();
      final isVerified = userStatus == 'LOCALLY_VERIFIED';
      final devices = await AppDatabase().getDevices();
      final hasUntrusted = devices.any((d) => d['status'] != 'TRUSTED');

      int score = 0;
      final factors = <SecurityFactorModel>[];

      // Factor 1: Biometría local (35 pts)
      if (hasBiometrics) {
        score += 35;
        factors.add(SecurityFactorModel(
          name: 'Biometría Configurada',
          description: 'El dispositivo cuenta con sensores biométricos activos',
          contribution: 35,
          status: 'POSITIVE',
        ));
      } else {
        factors.add(SecurityFactorModel(
          name: 'Biometría Ausente',
          description: 'Sin soporte o configuración de biometría en el dispositivo',
          contribution: 0,
          status: 'NEUTRAL',
        ));
      }

      // Factor 2: Bloqueo de pantalla seguro (25 pts)
      if (hasScreenLock) {
        score += 25;
        factors.add(SecurityFactorModel(
          name: 'Bloqueo de Pantalla Seguro',
          description: 'PIN, patrón o contraseña de pantalla configurado en el sistema',
          contribution: 25,
          status: 'POSITIVE',
        ));
      } else {
        factors.add(SecurityFactorModel(
          name: 'Bloqueo Inseguro',
          description: 'El dispositivo no cuenta con bloqueo de pantalla seguro',
          contribution: 0,
          status: 'NEGATIVE',
        ));
      }

      // Factor 3: Verificación de Identidad (25 pts)
      if (isVerified) {
        score += 25;
        factors.add(SecurityFactorModel(
          name: 'Identidad Verificada',
          description: 'Cotejo facial y prueba de vida completados con éxito',
          contribution: 25,
          status: 'POSITIVE',
        ));
      } else {
        factors.add(SecurityFactorModel(
          name: 'Identidad Pendiente',
          description: 'La prueba biométrica de identidad aún no fue completada',
          contribution: 0,
          status: 'NEUTRAL',
        ));
      }

      // Factor 4: Dispositivos de Confianza (15 pts)
      if (!hasUntrusted && devices.isNotEmpty) {
        score += 15;
        factors.add(SecurityFactorModel(
          name: 'Dispositivos de Confianza',
          description: 'Todos los dispositivos vinculados están autorizados',
          contribution: 15,
          status: 'POSITIVE',
        ));
      } else {
        factors.add(SecurityFactorModel(
          name: 'Dispositivos Pendientes',
          description: 'Existen dispositivos sin evaluar o pendientes de aprobación',
          contribution: 0,
          status: 'NEUTRAL',
        ));
      }

      score = score.clamp(0, 100);
      final String level = score >= 80 ? 'ALTO' : (score >= 50 ? 'MEDIO' : 'BAJO');
      final String levelDesc = score >= 80
          ? 'Nivel de seguridad óptimo para operaciones reguladas'
          : (score >= 50
              ? 'Nivel de seguridad intermedio. Recomendamos activar biometría y bloqueo de pantalla'
              : 'Nivel de seguridad bajo. Complete las verificaciones pendientes');

      return SecurityScoreModel(
        score: score,
        level: level,
        levelDescription: levelDesc,
        factors: factors,
      );
    }

    try {
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
