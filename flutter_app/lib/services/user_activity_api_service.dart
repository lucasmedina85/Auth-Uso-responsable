import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';

class UserActivityApiService {
  static final UserActivityApiService _instance = UserActivityApiService._internal();
  factory UserActivityApiService() => _instance;
  UserActivityApiService._internal();

  Dio get _dio => DioClient().dio;

  /// Obtiene la actividad real paginada y filtrada del usuario desde el backend
  Future<Map<String, dynamic>> getUserActivity({
    int page = 0,
    int size = 20,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
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
