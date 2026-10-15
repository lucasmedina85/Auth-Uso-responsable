import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/logic/local_risk_engine.dart';

void main() {
  group('LocalRiskEngine Tests', () {
    test('Happy path: optimal scores result in AUTORIZAR with score 0', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: false,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: true,
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
        now: DateTime.utc(2026, 10, 14, 18, 30), // UTC 18:30 -> ART 15:30 (fuera de noche)
      );

      expect(result.decision.name, equals('AUTORIZAR'));
      expect(result.compositeScore, equals(0));
    });

    test('Hard rule: Emulator detection immediately triggers BLOQUEAR with score 100', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: true,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: false,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: true,
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
      );

      expect(result.decision.name, equals('BLOQUEAR'));
      expect(result.compositeScore, equals(100));
      expect(result.hardRuleApplied, equals('EMULATOR_DETECTED'));
    });

    test('Hard rule: DNI blacklisted immediately triggers BLOQUEAR with score 100', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: true,
        isUserLocked: false,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: true,
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
      );

      expect(result.decision.name, equals('BLOQUEAR'));
      expect(result.compositeScore, equals(100));
      expect(result.hardRuleApplied, equals('DNI_BLACKLISTED'));
    });

    test('Hard rule: User locked immediately triggers BLOQUEAR with score 100', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: true,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: true,
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
      );

      expect(result.decision.name, equals('BLOQUEAR'));
      expect(result.compositeScore, equals(100));
      expect(result.hardRuleApplied, equals('USER_LOCKED_OUT'));
    });

    test('Intermediate risk: Non-latest document (50) lands in REVISIÓN threshold [50..79]', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: false,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: false, // +50
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
        now: DateTime.utc(2026, 10, 14, 17, 0), // UTC 17:00 -> ART 14:00 (fuera de noche)
      );

      expect(result.decision.name, equals('REVISIÓN'));
      expect(result.compositeScore, equals(50));
      expect(result.factorContributions['documentValidity'], equals(50));
    });

    test('High cumulative risk: Non-latest document (50) + Night schedule (20) + Behavioral (10) = 80 -> BLOQUEAR', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: false,
        livenessScore: 100,
        faceMatchScore: 100,
        isLatestDocument: false, // +50
        isVpnOrProxy: false,
        behavioralAdultScore: 0.20, // +10 (< 0.35)
        failedAttempts: 0,
        now: DateTime.utc(2026, 10, 14, 6, 30), // UTC 06:30 -> ART 03:30 (madrugada 03:00 a 06:00 ART) -> +20
      );

      expect(result.compositeScore, equals(80));
      expect(result.decision.name, equals('BLOQUEAR'));
      expect(result.factorContributions['schedule'], equals(20));
      expect(result.factorContributions['behavioral'], equals(10));
      expect(result.factorContributions['documentValidity'], equals(50));
    });

    test('Low liveness (score = 0) adds 100 points -> BLOQUEAR', () {
      final result = LocalRiskEngine.evaluateSimple(
        isEmulator: false,
        isRootOrCompromised: false,
        isDniBlacklisted: false,
        isUserLocked: false,
        livenessScore: 0, // +100
        faceMatchScore: 100,
        isLatestDocument: true,
        isVpnOrProxy: false,
        behavioralAdultScore: 0.90,
        failedAttempts: 0,
        now: DateTime.utc(2026, 10, 14, 15, 0), // ART 12:00
      );

      expect(result.compositeScore, equals(100));
      expect(result.decision.name, equals('BLOQUEAR'));
      expect(result.factorContributions['liveness'], equals(100));
    });
  });
}
