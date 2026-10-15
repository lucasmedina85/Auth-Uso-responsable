import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';

enum DemoScenario {
  EXITO,           // Validación exitosa determinista (AUTORIZAR)
  REVISION,        // Enviar a revisión manual (REVISIÓN)
  BLOQUEO_RIESGO,  // Bloqueo duro por riesgo / emulador (BLOQUEAR)
  SUPLANTACION,    // Alerta crítica de suplantación facial (SPOOFING_DETECTED)
  DNI_DENUNCIADO,  // Alerta crítica de DNI extraviado/denunciado (DNI_BLOCKED_STOLEN)
}

extension DemoScenarioExtension on DemoScenario {
  String get displayName {
    switch (this) {
      case DemoScenario.EXITO:
        return 'Validación Exitosa (AUTORIZAR)';
      case DemoScenario.REVISION:
        return 'Revisión Manual (REVISIÓN)';
      case DemoScenario.BLOQUEO_RIESGO:
        return 'Bloqueo por Riesgo (BLOQUEAR)';
      case DemoScenario.SUPLANTACION:
        return 'Alerta: Suplantación Facial';
      case DemoScenario.DNI_DENUNCIADO:
        return 'Alerta: DNI Denunciado';
    }
  }

  String get shortLabel {
    switch (this) {
      case DemoScenario.EXITO:
        return 'Éxito';
      case DemoScenario.REVISION:
        return 'Revisión';
      case DemoScenario.BLOQUEO_RIESGO:
        return 'Bloqueo';
      case DemoScenario.SUPLANTACION:
        return 'Suplantación';
      case DemoScenario.DNI_DENUNCIADO:
        return 'DNI Denunciado';
    }
  }
}

/// Servicio singleton para gestionar los escenarios del Modo Demostración.
class DemoModeService {
  static final DemoModeService _instance = DemoModeService._internal();
  factory DemoModeService() => _instance;
  DemoModeService._internal();

  /// Activo en modo local o en debug.
  bool get isDemoModeEnabled => AppConfig.isLocal || kDebugMode;

  final ValueNotifier<DemoScenario> currentScenarioNotifier =
      ValueNotifier<DemoScenario>(DemoScenario.EXITO);

  DemoScenario get currentScenario => currentScenarioNotifier.value;

  void setScenario(DemoScenario scenario) {
    currentScenarioNotifier.value = scenario;
  }
}
