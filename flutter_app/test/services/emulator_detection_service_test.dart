import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/services/emulator_detection_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.authenticator/security');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Real device detection: isEmulator is false and not blocked', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'checkEmulator') {
        return {
          'isEmulator': false,
          'score': 0.0,
          'reasons': <String>[],
        };
      }
      return null;
    });

    final result = await EmulatorDetectionService.checkEmulator();
    expect(result.isEmulator, isFalse);
    expect(result.score, equals(0.0));
    expect(result.reasons, isEmpty);
    expect(EmulatorDetectionService.rawEmulatorDetected, isFalse);
    expect(EmulatorDetectionService.isBlockedByEmulator, isFalse);
  });

  test('Emulator detected: isEmulator is true, reasons parsed, and blocked', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (call.method == 'checkEmulator') {
        return {
          'isEmulator': true,
          'score': 0.85,
          'reasons': ['BUILD_FINGERPRINT: generic', 'PROP_QEMU: 1', 'NO_SENSORS'],
        };
      }
      return null;
    });

    final result = await EmulatorDetectionService.checkEmulator();
    expect(result.isEmulator, isTrue);
    expect(result.score, equals(0.85));
    expect(result.reasons.length, equals(3));
    expect(result.reasons.contains('BUILD_FINGERPRINT: generic'), isTrue);
    expect(EmulatorDetectionService.rawEmulatorDetected, isTrue);
    expect(EmulatorDetectionService.isBlockedByEmulator, isTrue);
  });

  test('MissingPluginException falls back to non-blocked safe state', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      throw MissingPluginException();
    });

    final result = await EmulatorDetectionService.checkEmulator();
    expect(result.isEmulator, isFalse);
    expect(result.score, equals(0.0));
    expect(EmulatorDetectionService.isBlockedByEmulator, isFalse);
  });
}
