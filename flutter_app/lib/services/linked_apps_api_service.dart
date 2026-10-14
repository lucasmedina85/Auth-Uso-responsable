import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class LinkedAppsApiService {
  static final LinkedAppsApiService _instance = LinkedAppsApiService._internal();
  factory LinkedAppsApiService() => _instance;
  LinkedAppsApiService._internal();

  Dio get _dio => DioClient().dio;

  /// Obtiene la lista de aplicaciones OAuth vinculadas desde el backend (CU-0027)
  Future<List<Map<String, dynamic>>> getLinkedApplications() async {
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

  /// Desvincula una aplicación OAuth (revoca tokens emitidos y JTI en RevocationStore)
  Future<bool> unlinkApplication(String clientId) async {
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
