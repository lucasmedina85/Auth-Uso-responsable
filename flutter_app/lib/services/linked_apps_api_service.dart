import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/config/app_config.dart';
import '../core/database/app_database.dart';
import '../core/network/dio_client.dart';
import '../core/security/local_crypto_helper.dart';

class LinkedAppsApiService {
  static final LinkedAppsApiService _instance = LinkedAppsApiService._internal();
  factory LinkedAppsApiService() => _instance;
  LinkedAppsApiService._internal();

  Dio get _dio => DioClient().dio;

  /// Obtiene la lista de aplicaciones OAuth vinculadas (local o backend) (CU-0027)
  Future<List<Map<String, dynamic>>> getLinkedApplications() async {
    if (AppConfig.isLocal) {
      final apps = await AppDatabase().getLinkedApps();
      final oauthApps = apps.where((a) => a['type'] == 'OAUTH').toList();
      return oauthApps.map((a) => {
        'id': a['id'],
        'clientId': a['client_id'] ?? a['id'],
        'name': a['name'],
        'linkedAt': a['added_at'],
        'status': a['status'],
        'scopes': a['scopes'] ?? 'read:profile,verify:age',
        'tokenStatus': a['status'] == 'ACTIVE' ? 'VIGENTE' : 'REVOCADO',
        'lastUsedAt': a['added_at'],
      }).toList();
    }

    try {
      final response = await _dio.get('/oauth/linked-applications');
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (e) {
      log('Error al consultar aplicaciones OAuth vinculadas: $e');
      rethrow;
    }
  }

  /// Desvincula una aplicación OAuth (local o backend)
  Future<bool> unlinkApplication(String clientId) async {
    if (AppConfig.isLocal) {
      await AppDatabase().revokeLinkedApp(clientId);
      return true;
    }

    try {
      final response = await _dio.post('/oauth/unlink', data: {
        'clientId': clientId,
      });
      return response.statusCode == 200;
    } catch (e) {
      log('Error al desvincular aplicación OAuth: $e');
      rethrow;
    }
  }

  /// Descarga el registro forense certificado de aplicaciones vinculadas (CU-0048)
  Future<Map<String, dynamic>> exportLinkedApplicationsLog({
    String? reauthToken,
    String? startDate,
    String? endDate,
  }) async {
    if (AppConfig.isLocal) {
      final apps = await AppDatabase().getLinkedApps();
      final payloadData = {
        'userPseudonym': 'usr-demo-***',
        'dateRange': '${startDate ?? 'Inicio'} - ${endDate ?? 'Presente'}',
        'generatedAt': DateTime.now().toIso8601String(),
        'totalRecords': apps.length,
        'applications': apps,
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
        '/oauth/linked-applications/export',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: headers.isNotEmpty ? Options(headers: headers) : null,
      );
      if (response.statusCode == 200 && response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Respuesta inesperada al exportar log de aplicaciones vinculadas');
    } catch (e) {
      log('Error al exportar log certificado de aplicaciones vinculadas: $e');
      rethrow;
    }
  }
}
