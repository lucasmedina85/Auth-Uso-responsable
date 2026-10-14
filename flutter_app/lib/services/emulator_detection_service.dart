import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EmulatorCheckResult {
  final bool isEmulator;
  final double score;
  final List<String> reasons;
  final bool bypassed;

  const EmulatorCheckResult({
    required this.isEmulator,
    required this.score,
    required this.reasons,
    this.bypassed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'isEmulator': isEmulator,
      'score': score,
      'reasons': reasons,
      'bypassed': bypassed,
    };
  }

  @override
  String toString() =>
      'EmulatorCheckResult(isEmulator: $isEmulator, score: $score, reasons: $reasons, bypassed: $bypassed)';
}

class EmulatorDetectionService {
  static const MethodChannel _channel = MethodChannel('com.authenticator/security');

  static EmulatorCheckResult? _lastResult;
  static EmulatorCheckResult? get lastResult => _lastResult;

  /// Retorna si el último chequeo detectó emulador (sin considerar bypass, para señales de riesgo).
  static bool get rawEmulatorDetected => _lastResult?.isEmulator ?? false;

  /// Retorna si el chequeo concluyó que debe bloquearse (considerando bypass de desarrollo).
  static bool get isBlockedByEmulator =>
      (_lastResult?.isEmulator ?? false) && !(_lastResult?.bypassed ?? false);

  /// Ejecuta la detección heurística de emuladores (CU-0034).
  ///
  /// El bypass SOLO es permitido si kDebugMode es true Y se pasa
  /// --dart-define=BYPASS_EMULATOR_CHECK=true al compilar.
  /// En modo Release (kReleaseMode) o cuando kDebugMode es false, se ignora estrictamente.
  static Future<EmulatorCheckResult> checkEmulator() async {
    const bool defineBypass = bool.fromEnvironment('BYPASS_EMULATOR_CHECK', defaultValue: false);
    final bool canBypass = kDebugMode && defineBypass;

    try {
      final dynamic result = await _channel.invokeMethod('checkEmulator');
      if (result is Map) {
        final bool isEmu = result['isEmulator'] == true;
        final double score = (result['score'] as num?)?.toDouble() ?? (isEmu ? 1.0 : 0.0);
        final List<String> reasons = (result['reasons'] as List?)?.map((e) => e.toString()).toList() ?? [];

        final checkResult = EmulatorCheckResult(
          isEmulator: isEmu,
          score: score,
          reasons: reasons,
          bypassed: isEmu && canBypass,
        );

        _lastResult = checkResult;
        log('CU-0034 EmulatorCheck: isEmulator=$isEmu, score=$score, bypassed=${checkResult.bypassed}');
        return checkResult;
      }
    } on MissingPluginException {
      log('CU-0034 EmulatorCheck: MissingPluginException, assuming non-emulator or desktop mock.');
    } on PlatformException catch (e) {
      log('CU-0034 EmulatorCheck error: ${e.message}');
    } catch (e) {
      log('CU-0034 Unexpected error during emulator check: $e');
    }

    const fallbackResult = EmulatorCheckResult(
      isEmulator: false,
      score: 0.0,
      reasons: [],
      bypassed: false,
    );
    _lastResult = fallbackResult;
    return fallbackResult;
  }
}
