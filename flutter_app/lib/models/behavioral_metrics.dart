/// Métricas agregadas de comportamiento táctil y lectura (CU-0035).
///
/// IMPORTANTE (Privacidad):
/// Este modelo contiene ÚNICAMENTE métricas agregadas y estadísticas resumidas.
/// Por diseño y respeto a la privacidad del usuario, NO almacena coordenadas (x, y) crudas,
/// trayectorias completas ni marcas de tiempo individuales de los toques.
class BehavioralMetrics {
  final int totalTaps;
  final double avgTapDurationMs;
  final double avgMoveVelocity; // px/s
  final double avgPressure;
  final double tapPrecisionScore; // 0.0 a 1.0 (1.0 = alta estabilidad espacial en el toque)
  final int totalDwellTimeMs;
  final double behavioralAdultScore; // 0.0 a 1.0 (score heurístico complementario)

  const BehavioralMetrics({
    required this.totalTaps,
    required this.avgTapDurationMs,
    required this.avgMoveVelocity,
    required this.avgPressure,
    required this.tapPrecisionScore,
    required this.totalDwellTimeMs,
    required this.behavioralAdultScore,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalTaps': totalTaps,
      'avgTapDurationMs': double.parse(avgTapDurationMs.toStringAsFixed(2)),
      'avgMoveVelocity': double.parse(avgMoveVelocity.toStringAsFixed(2)),
      'avgPressure': double.parse(avgPressure.toStringAsFixed(2)),
      'tapPrecisionScore': double.parse(tapPrecisionScore.toStringAsFixed(2)),
      'totalDwellTimeMs': totalDwellTimeMs,
      'behavioralAdultScore': double.parse(behavioralAdultScore.toStringAsFixed(2)),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  @override
  String toString() =>
      'BehavioralMetrics(totalTaps: $totalTaps, avgDuration: ${avgTapDurationMs.toStringAsFixed(1)}ms, '
      'avgVelocity: ${avgMoveVelocity.toStringAsFixed(1)}px/s, precision: ${tapPrecisionScore.toStringAsFixed(2)}, '
      'dwellTime: ${totalDwellTimeMs}ms, adultScore: ${behavioralAdultScore.toStringAsFixed(2)})';
}
