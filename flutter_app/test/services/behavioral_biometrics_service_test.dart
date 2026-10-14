import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/services/behavioral_biometrics_service.dart';

void main() {
  late BehavioralBiometricsService service;

  setUp(() {
    service = BehavioralBiometricsService();
    service.reset();
  });

  test('Singleton instance integrity and initial clean state', () {
    final instance1 = BehavioralBiometricsService();
    final instance2 = BehavioralBiometricsService();
    expect(identical(instance1, instance2), isTrue);

    final metrics = service.getAggregatedMetrics();
    expect(metrics.totalTaps, equals(0));
    expect(metrics.avgTapDurationMs, equals(0.0));
    expect(metrics.avgMoveVelocity, equals(0.0));
  });

  test('Dwell time accumulates across screen entry and exit', () async {
    service.recordScreenEntry('LoginScreen');
    await Future.delayed(const Duration(milliseconds: 30));
    service.recordScreenExit();

    final metrics = service.getAggregatedMetrics();
    expect(metrics.totalDwellTimeMs, greaterThanOrEqualTo(25));
  });

  test('Pointer tap sequence accumulates taps and calculates precision', () async {
    service.onPointerDown(const PointerDownEvent(
      position: Offset(100, 200),
      pressure: 0.8,
    ));

    service.onPointerMove(const PointerMoveEvent(
      position: Offset(102, 201),
      pressure: 0.85,
    ));

    await Future.delayed(const Duration(milliseconds: 100));

    service.onPointerUp(const PointerUpEvent(
      position: Offset(102, 201),
    ));

    final metrics = service.getAggregatedMetrics();
    expect(metrics.totalTaps, equals(1));
    expect(metrics.avgTapDurationMs, greaterThanOrEqualTo(80.0));
    expect(metrics.avgPressure, greaterThan(0.0));
    expect(metrics.tapPrecisionScore, greaterThan(0.5));
  });

  test('Privacy guarantee: only aggregated metrics exposed, no raw coordinate traces', () {
    service.onPointerDown(const PointerDownEvent(position: Offset(55, 66)));
    service.onPointerUp(const PointerUpEvent(position: Offset(55, 66)));

    final json = service.getAggregatedMetrics().toJson();
    expect(json.containsKey('rawCoordinates'), isFalse);
    expect(json.containsKey('events'), isFalse);
    expect(json.containsKey('touchHistory'), isFalse);
    expect(json.containsKey('totalTaps'), isTrue);
    expect(json.containsKey('behavioralAdultScore'), isTrue);
  });

  test('Adult score is bounded within [0.0, 1.0] and reset restores default', () {
    final initialScore = service.calculateAdultScore();
    expect(initialScore, inInclusiveRange(0.0, 1.0));

    service.recordScreenEntry('TermsScreen');
    service.onPointerDown(const PointerDownEvent(position: Offset(150, 300)));
    service.onPointerUp(const PointerUpEvent(position: Offset(150, 300)));
    service.recordScreenExit();

    final metrics = service.getAggregatedMetrics();
    expect(metrics.behavioralAdultScore, inInclusiveRange(0.0, 1.0));

    service.reset();
    final resetMetrics = service.getAggregatedMetrics();
    expect(resetMetrics.totalTaps, equals(0));
    expect(resetMetrics.totalDwellTimeMs, equals(0));
  });
}
