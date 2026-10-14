import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/models/device_model.dart';

void main() {
  group('DeviceModel Tests', () {
    test('fromJson parses full payload correctly', () {
      final json = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'deviceHash': 'abcdef123456',
        'deviceName': 'Google Pixel 7',
        'manufacturer': 'Google',
        'osVersion': 'Android 14',
        'deviceType': 'MOBILE',
        'status': 'TRUSTED',
        'isCurrent': true,
        'firstSeenAt': '2026-10-13T10:00:00',
        'lastSeenAt': '2026-10-13T12:00:00',
      };

      final device = DeviceModel.fromJson(json);

      expect(device.id, '123e4567-e89b-12d3-a456-426614174000');
      expect(device.deviceHash, 'abcdef123456');
      expect(device.deviceName, 'Google Pixel 7');
      expect(device.manufacturer, 'Google');
      expect(device.osVersion, 'Android 14');
      expect(device.deviceType, 'MOBILE');
      expect(device.status, 'TRUSTED');
      expect(device.isCurrent, isTrue);
      expect(device.firstSeenAt, isNotNull);
      expect(device.lastSeenAt, isNotNull);
    });

    test('DeviceAlertModel parses alert payload correctly', () {
      final json = {
        'id': 'alert-001',
        'deviceName': 'iPhone 15 Pro',
        'type': 'PENDING_APPROVAL',
        'message': 'Nuevo dispositivo pendiente de confirmación',
        'timestamp': '2026-10-13T14:30:00',
      };

      final alert = DeviceAlertModel.fromJson(json);

      expect(alert.id, 'alert-001');
      expect(alert.deviceName, 'iPhone 15 Pro');
      expect(alert.type, 'PENDING_APPROVAL');
      expect(alert.message, 'Nuevo dispositivo pendiente de confirmación');
      expect(alert.timestamp, isNotNull);
    });
  });
}
