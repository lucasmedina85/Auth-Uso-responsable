import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../services/session_service.dart';
import 'dart:developer';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;
  bool _isRefreshing = false;
  
  // baseUrl from --dart-define (or default to 10.0.2.2 for Android emulator testing)
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    // Only allow HTTP in debug mode. In release, enforce HTTPS.
    if (!kDebugMode && baseUrl.startsWith('http://')) {
      throw Exception('HTTP sin TLS no está permitido en producción');
    }

    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));

    dio.interceptors.add(QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SessionService.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          log('401 Unauthorized interceptado. Iniciando refresh...');
          // Si estamos refrescando, las peticiones concurrentes quedan encoladas automáticamente
          // por el QueuedInterceptorsWrapper hasta que resolvamos o rechacemos este error.
          
          bool refreshed = await _refreshToken();
          if (refreshed) {
            // Reintentar la solicitud original con el nuevo token
            final newToken = await SessionService.getAccessToken();
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            
            try {
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
            // Falló el refresh, desloguear (limpiar storage) y continuar con el error
            await SessionService.clearTokens();
            return handler.next(e);
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final tokens = await SessionService.getTokens();
      if (tokens['refreshToken'] == null) {
        return false;
      }
      
      final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
      final response = await refreshDio.post('/auth/refresh', data: {
        'refreshToken': tokens['refreshToken'],
      });

      if (response.statusCode == 200) {
        await SessionService.saveTokens(
          response.data['accessToken'], 
          response.data['refreshToken']
        );
        return true;
      }
    } catch (e) {
      log('Error refrescando token: $e');
    } finally {
      _isRefreshing = false;
    }
    return false;
  }
}
