import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/database/app_database.dart';
import '../core/network/dio_client.dart';
import '../core/security/local_crypto_helper.dart';

class UserActivityApiService {
  static final UserActivityApiService _instance = UserActivityApiService._internal();
  factory UserActivityApiService() => _instance;
  UserActivityApiService._internal();

  Dio get _dio => DioClient().dio;

  /// Obtiene la actividad real paginada y filtrada del usuario (local o remota)
  Future<Map<String, dynamic>> getUserActivity({
    int page = 0,
    int size = 20,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    if (AppConfig.isLocal) {
      final logs = await AppDatabase().getActivityLogs(
        type: type,
        page: page,
        size: size,
      );
      final events = logs.map((l) => {
        'id': l['id'],
        'type': l['type'],
        'action': l['action'],
        'description': l['description'],
        'ipAddress': l['ip_address'],
        'deviceId': l['device_id'],
        'timestamp': l['timestamp'],
        'severity': l['severity'],
      }).toList();

      return {
        'events': events,
        'page': page,
        'size': size,
        'totalElements': events.length,
        'totalPages': 1,
        'hasNext': false,
      };
    }

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'size': size,
      };
      if (type != null && type.isNotEmpty && type != 'ALL') {
        queryParams['type'] = type;
      }
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final response = await _dio.get('/users/activity', queryParameters: queryParams);
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {
        'events': [],
        'page': page,
        'size': size,
        'totalElements': 0,
        'totalPages': 0,
        'hasNext': false,
      };
    } catch (e) {
      log('Error al consultar actividad de usuario: $e');
      rethrow;
    }
  }

  /// Descarga el registro forense certificado de actividad de la cuenta (CU-0048)
  Future<Map<String, dynamic>> exportUserActivity({
    String? reauthToken,
    String? startDate,
    String? endDate,
  }) async {
    if (AppConfig.isLocal) {
      final logs = await AppDatabase().getActivityLogs(page: 0, size: 100);
      final payloadData = {
        'userPseudonym': 'usr-demo-***',
        'dateRange': '${startDate ?? 'Inicio'} - ${endDate ?? 'Presente'}',
        'generatedAt': DateTime.now().toIso8601String(),
        'totalRecords': logs.length,
        'events': logs,
      };
      final payloadJson = jsonEncode(payloadData);
      final exportHash = LocalCryptoHelper.sha256Hex(payloadJson);
      final signature = LocalCryptoHelper.hmacSha256Hex('SIP_LOCAL_OFFLINE_SECRET_KEY', exportHash);

      return {
        'integrityHashSha256': exportHash,
        'signature': signature,
        'signingAlgorithm': 'RS256 (Simulado Offline)',
        'payload': payloadData,
      };
    }

    try {
      final queryParams = <String, dynamic>{};
      if (startDate != null && startDate.isNotEmpty) {
        queryParams['startDate'] = startDate;
      }
      if (endDate != null && endDate.isNotEmpty) {
        queryParams['endDate'] = endDate;
      }

      final headers = <String, dynamic>{};
      if (reauthToken != null && reauthToken.isNotEmpty) {
        headers['X-Reauth-Token'] = reauthToken;
      }

      final response = await _dio.get(
        '/users/activity/export',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers.isNotEmpty ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Respuesta inesperada al exportar log de actividad de usuario');
    } catch (e) {
      log('Error al exportar log certificado de actividad: $e');
      rethrow;
    }
  }
}
