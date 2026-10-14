import 'dart:math';
import 'package:flutter/gestures.dart';
import '../models/behavioral_metrics.dart';

/// Servicio de Evaluación de Comportamiento de Interfaz (CU-0035).
///
/// Captura dinámicas táctiles agregadas (velocidad, precisión de toques, presión)
/// y tiempos de lectura/permanencia por pantalla.
///
/// GARANTÍA DE PRIVACIDAD:
/// No se almacenan coordenadas espaciales individuales ni secuencias de eventos crudos.
/// Toda la información se procesa en tiempo real como acumuladores estadísticos.
///
/// NATURALEZA DE LA SEÑAL:
/// El score heurístico es una señal estrictamente COMPLEMENTARIA y NUNCA DECISIVA por sí sola.
/// Su objetivo es proveer contexto adicional al motor de riesgo (CU-0023) sin generar
/// bloqueos unilaterales.
class BehavioralBiometricsService {
  static final BehavioralBiometricsService _instance = BehavioralBiometricsService._internal();
  factory BehavioralBiometricsService() => _instance;
  BehavioralBiometricsService._internal();

  int _totalTaps = 0;
  double _totalTapDurationMs = 0.0;
  double _totalJitterDistance = 0.0;
  double _totalPressure = 0.0;

  double _totalMoveDistance = 0.0;
  double _totalMoveDurationMs = 0.0;

  int _totalDwellTimeMs = 0;
  DateTime? _screenEntryTime;

  // Variables transitorias de toque en curso (se descartan al finalizar el toque)
  Offset? _activePointerDownPos;
  DateTime? _activePointerDownTime;
  Offset? _lastMovePos;
  DateTime? _lastMoveTime;

  /// Registra el ingreso a una pantalla para medir tiempo de lectura/permanencia.
  void recordScreenEntry(String screenName) {
    recordScreenExit(); // Cierra pantalla previa si quedó abierta
    _screenEntryTime = DateTime.now();
  }

  /// Registra la salida de una pantalla y acumula el tiempo de permanencia.
  void recordScreenExit() {
    if (_screenEntryTime != null) {
      final elapsed = DateTime.now().difference(_screenEntryTime!).inMilliseconds;
      _totalDwellTimeMs += elapsed;
      _screenEntryTime = null;
    }
  }

  /// Evento al apoyar el dedo sobre la pantalla.
  void onPointerDown(PointerDownEvent event) {
    _activePointerDownPos = event.position;
    _activePointerDownTime = DateTime.now();
    _lastMovePos = event.position;
    _lastMoveTime = DateTime.now();
  }

  /// Evento al desplazar el dedo sobre la pantalla.
  void onPointerMove(PointerMoveEvent event) {
    if (_lastMovePos != null && _lastMoveTime != null) {
      final now = DateTime.now();
      final dt = now.difference(_lastMoveTime!).inMilliseconds;
      if (dt > 0) {
        final dx = event.position.dx - _lastMovePos!.dx;
        final dy = event.position.dy - _lastMovePos!.dy;
        final dist = sqrt(dx * dx + dy * dy);

        _totalMoveDistance += dist;
        _totalMoveDurationMs += dt;
      }
    }
    _lastMovePos = event.position;
    _lastMoveTime = DateTime.now();
  }

  /// Evento al levantar el dedo de la pantalla.
  void onPointerUp(PointerUpEvent event) {
    if (_activePointerDownPos != null && _activePointerDownTime != null) {
      final now = DateTime.now();
      final durationMs = now.difference(_activePointerDownTime!).inMilliseconds.toDouble();
      final dx = event.position.dx - _activePointerDownPos!.dx;
      final dy = event.position.dy - _activePointerDownPos!.dy;
      final jitter = sqrt(dx * dx + dy * dy);

      _totalTaps++;
      _totalTapDurationMs += durationMs;
      _totalJitterDistance += jitter;
      _totalPressure += event.pressure > 0.0 ? event.pressure : 1.0;
    }

    // Limpieza estricta de coordenadas transitorias (no retención de datos crudos)
    _activePointerDownPos = null;
    _activePointerDownTime = null;
    _lastMovePos = null;
    _lastMoveTime = null;
  }

  /// Calcula el score heurístico de patrón adulto/menor (0.0 a 1.0).
  ///
  /// SEÑAL COMPLEMENTARIA:
  /// - Adulto: toques estables (duración 80-350ms, bajo jitter espacial),
  ///   velocidad controlada y tiempo de lectura adecuado (> 2.5s).
  /// - Menor / Errático: ráfagas muy rápidas o toques muy prolongados,
  ///   alto jitter por falta de motricidad fina, saltos impulsivos (< 500ms).
  double calculateAdultScore() {
    if (_totalTaps < 2 && _totalDwellTimeMs < 1000) {
      return 0.85; // Valor neutro/seguro por defecto si hay poca interacción
    }

    final avgDuration = _totalTaps > 0 ? _totalTapDurationMs / _totalTaps : 150.0;
    final avgJitter = _totalTaps > 0 ? _totalJitterDistance / _totalTaps : 5.0;
    final avgVel = _totalMoveDurationMs > 0
        ? (_totalMoveDistance / (_totalMoveDurationMs / 1000.0))
        : 200.0;

    // 1. Factor de duración de toque (óptimo 70ms - 350ms)
    double durationScore = 1.0;
    if (avgDuration < 40.0 || avgDuration > 600.0) {
      durationScore = 0.4;
    } else if (avgDuration < 70.0 || avgDuration > 400.0) {
      durationScore = 0.7;
    }

    // 2. Factor de precisión espacial (jitter promedio bajo = alta precisión)
    final precisionScore = (1.0 - (avgJitter / 35.0)).clamp(0.2, 1.0);

    // 3. Factor de velocidad de desplazamiento (óptimo < 2000 px/s)
    final velocityScore = avgVel <= 1800.0 ? 1.0 : (1.0 - ((avgVel - 1800.0) / 3000.0)).clamp(0.3, 1.0);

    // 4. Factor de tiempo de lectura / permanencia
    final dwellScore = _totalDwellTimeMs >= 3000
        ? 1.0
        : (_totalDwellTimeMs / 3000.0).clamp(0.3, 1.0);

    final score = (durationScore * 0.25) +
        (precisionScore * 0.35) +
        (velocityScore * 0.15) +
        (dwellScore * 0.25);

    return score.clamp(0.0, 1.0);
  }

  /// Retorna las métricas agregadas consolidadas hasta el momento.
  BehavioralMetrics getAggregatedMetrics() {
    final avgDuration = _totalTaps > 0 ? _totalTapDurationMs / _totalTaps : 0.0;
    final avgJitter = _totalTaps > 0 ? _totalJitterDistance / _totalTaps : 0.0;
    final avgPressure = _totalTaps > 0 ? _totalPressure / _totalTaps : 1.0;
    final avgVel = _totalMoveDurationMs > 0
        ? (_totalMoveDistance / (_totalMoveDurationMs / 1000.0))
        : 0.0;

    final precisionScore = (1.0 - (avgJitter / 35.0)).clamp(0.0, 1.0);
    final adultScore = calculateAdultScore();

    // Actualiza tiempo de lectura acumulado con la pantalla activa actual si aplica
    var currentDwell = _totalDwellTimeMs;
    if (_screenEntryTime != null) {
      currentDwell += DateTime.now().difference(_screenEntryTime!).inMilliseconds;
    }

    return BehavioralMetrics(
      totalTaps: _totalTaps,
      avgTapDurationMs: avgDuration,
      avgMoveVelocity: avgVel,
      avgPressure: avgPressure,
      tapPrecisionScore: precisionScore,
      totalDwellTimeMs: currentDwell,
      behavioralAdultScore: adultScore,
    );
  }

  /// Reinicia los acumuladores (por ejemplo al cerrar sesión o iniciar nueva validación).
  void reset() {
    _totalTaps = 0;
    _totalTapDurationMs = 0.0;
    _totalJitterDistance = 0.0;
    _totalPressure = 0.0;
    _totalMoveDistance = 0.0;
    _totalMoveDurationMs = 0.0;
    _totalDwellTimeMs = 0;
    _screenEntryTime = null;
    _activePointerDownPos = null;
    _activePointerDownTime = null;
    _lastMovePos = null;
    _lastMoveTime = null;
  }
}
