import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:authenticator_juego_responsable/core/config/app_config.dart';
import 'package:authenticator_juego_responsable/core/network/dio_client.dart';

void main() {
  group('Zero Network Offline Enforcement Tests', () {
    test('When AppConfig.isLocal is true, Dio immediately rejects network requests', () async {
      expect(AppConfig.isLocal, isTrue);

      final dio = DioClient().dio;

      // Attempting any GET call in local mode must throw DioException with cancel type
      expect(
        () async => await dio.get('/test-endpoint'),
        throwsA(isA<DioException>().having(
          (e) => e.type,
          'type',
          equals(DioExceptionType.cancel),
        )),
      );

      // Attempting any POST call in local mode must also throw DioException with cancel type
      expect(
        () async => await dio.post('/test-endpoint', data: {'key': 'val'}),
        throwsA(isA<DioException>().having(
          (e) => e.type,
          'type',
          equals(DioExceptionType.cancel),
        )),
      );
    });
  });
}
