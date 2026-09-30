import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../services/session_service.dart';
import 'dart:developer';
import 'dart:async';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late Dio dio;
  bool _isRefreshing = false;
  
  // baseUrl from --dart-define (or default to 10.0.2.2 for Android emulator testing)
  static const String baseUrl = String.fromEnvironment('API_URL', defaultValue: 'http://10.0.2.2:8080');

  // Global event stream for auth failures like Concurrent Access
  static final StreamController<String> authEventStream = StreamController<String>.broadcast();

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
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
          bool refreshed = await _refreshToken();
          if (refreshed) {
            final newToken = await SessionService.getAccessToken();
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
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
    } on DioException catch (e) {
      log('Error refrescando token: $e');
      if (e.response?.statusCode == 401) {
        // Trigger concurrent access or generic revocation alert
        authEventStream.add('CONCURRENT_ACCESS');
      }
    } catch (e) {
      log('Error generico refrescando token: $e');
    } finally {
      _isRefreshing = false;
    }
    return false;
  }
}
