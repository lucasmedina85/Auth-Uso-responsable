import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceIntegrityResult {
  final bool isCompromised;
  final bool isEmulator;
  final bool isRooted;
  final double score;
  final List<String> reasons;
  final bool bypassed;

  const DeviceIntegrityResult({
    required this.isCompromised,
    required this.isEmulator,
    required this.isRooted,
    required this.score,
    required this.reasons,
    this.bypassed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'isCompromised': isCompromised,
      'isEmulator': isEmulator,
      'isRooted': isRooted,
      'score': score,
      'reasons': reasons,
      'bypassed': bypassed,
    };
  }

  @override
  String toString() =>
      'DeviceIntegrityResult(isCompromised: $isCompromised, isEmulator: $isEmulator, isRooted: $isRooted, score: $score, reasons: $reasons, bypassed: $bypassed)';
}

class DeviceIntegrityService {
  static const MethodChannel _channel = MethodChannel('com.authenticator/device_integrity');

  static DeviceIntegrityResult? _lastResult;
  static DeviceIntegrityResult? get lastResult => _lastResult;

  static bool get rawCompromised => _lastResult?.isCompromised ?? false;
  static bool get isBlocked =>
      (_lastResult?.isCompromised ?? false) && !(_lastResult?.bypassed ?? false);

  static Future<DeviceIntegrityResult> checkIntegrity() async {
    const bool defineBypass = bool.fromEnvironment('BYPASS_EMULATOR_CHECK', defaultValue: false);
    const bool canBypass = kDebugMode && defineBypass;

    try {
      final dynamic result = await _channel.invokeMethod('checkDeviceIntegrity');
      if (result is Map) {
        final bool isCompromised = result['isCompromised'] == true;
        final bool isEmu = result['isEmulator'] == true;
        final bool isRoot = result['isRooted'] == true;
        final double score = (result['score'] as num?)?.toDouble() ?? (isCompromised ? 1.0 : 0.0);
        final List<String> reasons = (result['reasons'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final checkResult = DeviceIntegrityResult(
          isCompromised: isCompromised,
          isEmulator: isEmu,
          isRooted: isRoot,
          score: score,
          reasons: reasons,
          bypassed: isCompromised && canBypass,
        );

        _lastResult = checkResult;
        log('DeviceIntegrityCheck: isCompromised=$isCompromised (emu=$isEmu, root=$isRoot), score=$score, bypassed=${checkResult.bypassed}');
        return checkResult;
      }
    } on MissingPluginException {
      log('DeviceIntegrityCheck: MissingPluginException, assuming non-compromised or desktop mock.');
    } on PlatformException catch (e) {
      log('DeviceIntegrityCheck error: ${e.message}');
    } catch (e) {
      log('Unexpected error during device integrity check: $e');
    }

    const fallbackResult = DeviceIntegrityResult(
      isCompromised: false,
      isEmulator: false,
      isRooted: false,
      score: 0.0,
      reasons: [],
      bypassed: false,
    );
    _lastResult = fallbackResult;
    return fallbackResult;
  }
}
