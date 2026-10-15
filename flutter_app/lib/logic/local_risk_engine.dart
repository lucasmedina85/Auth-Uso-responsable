import 'dart:math';

/// Decisión de riesgo canónica (CU-0023).
enum LocalRiskDecision {
  AUTORIZAR,
  REVISION,
  BLOQUEAR,
}

extension LocalRiskDecisionExtension on LocalRiskDecision {
  String get name {
    switch (this) {
      case LocalRiskDecision.AUTORIZAR:
        return 'AUTORIZAR';
      case LocalRiskDecision.REVISION:
        return 'REVISIÓN';
      case LocalRiskDecision.BLOQUEAR:
        return 'BLOQUEAR';
    }
  }
}

class LocalVerificationInput {
  final int? livenessScore;
  final int? faceMatchScore;
  final bool? isLatestDocument;
  final bool? emulatorDetected;
  final bool? deviceCompromised;
  final bool? clientVpnDetected;
  final bool? clientProxyDetected;
  final double? behavioralAdultScore;
  final int? failedFaceAttempts;
  final bool? dniBlacklisted;
  final bool? userLockedOut;

  LocalVerificationInput({
    this.livenessScore,
    this.faceMatchScore,
    this.isLatestDocument,
    this.emulatorDetected,
    this.deviceCompromised,
    this.clientVpnDetected,
    this.clientProxyDetected,
    this.behavioralAdultScore,
    this.failedFaceAttempts,
    this.dniBlacklisted,
    this.userLockedOut,
  });
}

class LocalRiskBreakdown {
  final int compositeScore;
  final LocalRiskDecision decision;
  final String? hardRuleApplied;
  final Map<String, int> factorContributions;
  final Map<String, String> factorStatus;
  final List<Map<String, dynamic>> details;
  final DateTime evaluatedAt;

  LocalRiskBreakdown({
    required this.compositeScore,
    required this.decision,
    this.hardRuleApplied,
    required this.factorContributions,
    required this.factorStatus,
    required this.details,
    required this.evaluatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'compositeScore': compositeScore,
      'decision': decision.name,
      'hardRuleApplied': hardRuleApplied,
      'factorContributions': factorContributions,
      'factorStatus': factorStatus,
      'details': details,
      'evaluatedAt': evaluatedAt.toIso8601String(),
    };
  }
}

/// Motor de riesgo local compuesto (CU-0023) ejecutado 100% en Dart offline.
/// Replica fielmente los pesos, umbrales y políticas de RiskEngineService.java.
class LocalRiskEngine {
  final int reviewThreshold;
  final int blockThreshold;
  final int weightLiveness;
  final int weightFaceMatch;
  final int weightDocumentNotLatest;
  final int weightScheduleNight;
  final int weightScheduleSchool;
  final int weightNetworkHigh;
  final int weightNetworkMedium;
  final int weightNetworkClientUntrusted;
  final int weightBehaviorLowAdult;
  final int weightFacialFailedAttempts;
  final double thresholdBehaviorAdultMin;

  final String missingPolicyLiveness;
  final String missingPolicyFaceMatch;
  final String missingPolicyDocument;
  final String missingPolicyNetwork;
  final String missingPolicyBehavior;

  final int missingPenaltyLiveness;
  final int missingPenaltyFaceMatch;
  final int missingPenaltyDocument;
  final int missingPenaltyNetwork;
  final int missingPenaltyBehavior;

  LocalRiskEngine({
    this.reviewThreshold = 50,
    this.blockThreshold = 80,
    this.weightLiveness = 100,
    this.weightFaceMatch = 100,
    this.weightDocumentNotLatest = 50,
    this.weightScheduleNight = 20,
    this.weightScheduleSchool = 10,
    this.weightNetworkHigh = 30,
    this.weightNetworkMedium = 15,
    this.weightNetworkClientUntrusted = 5,
    this.weightBehaviorLowAdult = 10,
    this.weightFacialFailedAttempts = 15,
    this.thresholdBehaviorAdultMin = 0.35,
    this.missingPolicyLiveness = 'PENALIZE',
    this.missingPolicyFaceMatch = 'PENALIZE',
    this.missingPolicyDocument = 'PENALIZE',
    this.missingPolicyNetwork = 'IGNORE',
    this.missingPolicyBehavior = 'IGNORE',
    this.missingPenaltyLiveness = 50,
    this.missingPenaltyFaceMatch = 50,
    this.missingPenaltyDocument = 50,
    this.missingPenaltyNetwork = 10,
    this.missingPenaltyBehavior = 10,
  });

  /// Método estático de conveniencia para evaluación rápida y pruebas unitarias.
  static LocalRiskBreakdown evaluateSimple({
    bool? isEmulator,
    bool? isRootOrCompromised,
    bool? isDniBlacklisted,
    bool? isUserLocked,
    int? livenessScore,
    int? faceMatchScore,
    bool? isLatestDocument,
    bool? isVpnOrProxy,
    double? behavioralAdultScore,
    int? failedAttempts,
    DateTime? now,
  }) {
    final engine = LocalRiskEngine();
    return engine.evaluate(
      LocalVerificationInput(
        emulatorDetected: isEmulator,
        deviceCompromised: isRootOrCompromised,
        dniBlacklisted: isDniBlacklisted,
        userLockedOut: isUserLocked,
        livenessScore: livenessScore,
        faceMatchScore: faceMatchScore,
        isLatestDocument: isLatestDocument,
        clientVpnDetected: isVpnOrProxy,
        clientProxyDetected: isVpnOrProxy,
        behavioralAdultScore: behavioralAdultScore,
        failedFaceAttempts: failedAttempts,
      ),
      now,
    );
  }

  LocalRiskBreakdown evaluate(LocalVerificationInput input, [DateTime? testDateTime]) {
    final now = testDateTime ?? DateTime.now();
    // Conversión a zona horaria de Buenos Aires (UTC-3)
    final artTime = now.toUtc().subtract(const Duration(hours: 3));

    final details = <Map<String, dynamic>>[];
    final factorContributions = <String, int>{};
    final factorStatus = <String, String>{};

    // 1. REGLA DURA: Emulador (CU-0034) o Dispositivo Comprometido / Root (CU-0033)
    final isDeviceCompromised = (input.emulatorDetected == true) || (input.deviceCompromised == true);
    if (isDeviceCompromised) {
      final ruleReason = input.emulatorDetected == true ? 'EMULATOR_DETECTED' : 'DEVICE_COMPROMISED';
      final detailsText = input.emulatorDetected == true
          ? 'Emulador detectado en entorno de ejecución (regla dura CU-0034)'
          : 'Dispositivo comprometido / root detectado (regla dura CU-0033)';

      details.add({
        'factorName': 'DEVICE_INTEGRITY',
        'contribution': 100,
        'maxWeight': 100,
        'status': 'HARD_RULE_TRIGGERED',
        'details': detailsText,
      });
      factorContributions['device_integrity'] = 100;
      factorStatus['device_integrity'] = 'HARD_RULE_TRIGGERED';

      return LocalRiskBreakdown(
        compositeScore: 100,
        decision: LocalRiskDecision.BLOQUEAR,
        hardRuleApplied: ruleReason,
        factorContributions: factorContributions,
        factorStatus: factorStatus,
        details: details,
        evaluatedAt: now,
      );
    }

    // REGLA DURA: DNI en lista negra (CU-0043)
    if (input.dniBlacklisted == true) {
      details.add({
        'factorName': 'DNI_BLACKLISTED',
        'contribution': 100,
        'maxWeight': 100,
        'status': 'HARD_RULE_TRIGGERED',
        'details': 'DNI presente en lista negra de fraude (regla dura CU-0043)',
      });
      factorContributions['dni_blacklist'] = 100;
      factorStatus['dni_blacklist'] = 'HARD_RULE_TRIGGERED';

      return LocalRiskBreakdown(
        compositeScore: 100,
        decision: LocalRiskDecision.BLOQUEAR,
        hardRuleApplied: 'DNI_BLACKLISTED',
        factorContributions: factorContributions,
        factorStatus: factorStatus,
        details: details,
        evaluatedAt: now,
      );
    }

    // REGLA DURA: Bloqueo de usuario (CU-0045)
    if (input.userLockedOut == true) {
      details.add({
        'factorName': 'USER_LOCKED_OUT',
        'contribution': 100,
        'maxWeight': 100,
        'status': 'HARD_RULE_TRIGGERED',
        'details': 'Usuario con bloqueo de seguridad temporal activo (regla dura CU-0045)',
      });
      factorContributions['user_lockout'] = 100;
      factorStatus['user_lockout'] = 'HARD_RULE_TRIGGERED';

      return LocalRiskBreakdown(
        compositeScore: 100,
        decision: LocalRiskDecision.BLOQUEAR,
        hardRuleApplied: 'USER_LOCKED_OUT',
        factorContributions: factorContributions,
        factorStatus: factorStatus,
        details: details,
        evaluatedAt: now,
      );
    }

    // 2. BIOMETRÍA: Liveness Score (CU-0014)
    int livenessContrib = 0;
    String livenessStatus;
    String livenessDetails;
    if (input.livenessScore != null) {
      final score = input.livenessScore!.clamp(0, 100);
      livenessContrib = (((100.0 - score) / 100.0) * weightLiveness).round();
      livenessStatus = 'EVALUATED';
      livenessDetails = 'Score liveness: $score / 100 (contribución: $livenessContrib, máx: $weightLiveness)';
    } else {
      if (missingPolicyLiveness.toUpperCase() == 'PENALIZE') {
        livenessContrib = missingPenaltyLiveness;
        livenessStatus = 'MISSING_PENALIZED';
        livenessDetails = 'Liveness no provisto (penalizado por omisión de señal crítica)';
      } else {
        livenessContrib = 0;
        livenessStatus = 'MISSING_IGNORED';
        livenessDetails = 'Liveness no provisto (ignorado por política)';
      }
    }
    details.add({
      'factorName': 'LIVENESS',
      'contribution': livenessContrib,
      'maxWeight': weightLiveness,
      'status': livenessStatus,
      'details': livenessDetails,
    });
    factorContributions['liveness'] = livenessContrib;
    factorStatus['liveness'] = livenessStatus;

    // 3. BIOMETRÍA: Face Match Score (CU-0015)
    int faceMatchContrib = 0;
    String faceMatchStatus;
    String faceMatchDetails;
    if (input.faceMatchScore != null) {
      final score = input.faceMatchScore!.clamp(0, 100);
      faceMatchContrib = (((100.0 - score) / 100.0) * weightFaceMatch).round();
      faceMatchStatus = 'EVALUATED';
      faceMatchDetails = 'Score cotejo facial: $score / 100 (contribución: $faceMatchContrib, máx: $weightFaceMatch)';
    } else {
      if (missingPolicyFaceMatch.toUpperCase() == 'PENALIZE') {
        faceMatchContrib = missingPenaltyFaceMatch;
        faceMatchStatus = 'MISSING_PENALIZED';
        faceMatchDetails = 'Cotejo facial no provisto (penalizado por omisión de señal crítica)';
      } else {
        faceMatchContrib = 0;
        faceMatchStatus = 'MISSING_IGNORED';
        faceMatchDetails = 'Cotejo facial no provisto (ignorado por política)';
      }
    }
    details.add({
      'factorName': 'FACE_MATCH',
      'contribution': faceMatchContrib,
      'maxWeight': weightFaceMatch,
      'status': faceMatchStatus,
      'details': faceMatchDetails,
    });
    factorContributions['faceMatch'] = faceMatchContrib;
    factorStatus['faceMatch'] = faceMatchStatus;

    // 4. VIGENCIA DOCUMENTAL: Tri-estado (CU-0009)
    int docContrib = 0;
    String docStatus;
    String docDetails;
    if (input.isLatestDocument == false) {
      docContrib = weightDocumentNotLatest;
      docStatus = 'EVALUATED';
      docDetails = 'Documento no vigente o desactualizado';
    } else if (input.isLatestDocument == true) {
      docContrib = 0;
      docStatus = 'EVALUATED';
      docDetails = 'Documento vigente y confirmado';
    } else {
      if (missingPolicyDocument.toUpperCase() == 'PENALIZE') {
        docContrib = missingPenaltyDocument;
        docStatus = 'MISSING_PENALIZED';
        docDetails = 'Vigencia de documento no provista (penalizado por omisión de señal crítica)';
      } else {
        docContrib = 0;
        docStatus = 'MISSING_IGNORED';
        docDetails = 'Vigencia de documento desconocida o delegada (no punible)';
      }
    }
    details.add({
      'factorName': 'DOCUMENT_VALIDITY',
      'contribution': docContrib,
      'maxWeight': weightDocumentNotLatest,
      'status': docStatus,
      'details': docDetails,
    });
    factorContributions['documentValidity'] = docContrib;
    factorStatus['documentValidity'] = docStatus;

    // 5. HORARIO DE SOLICITUD (CU-0022) (Horas en Buenos Aires)
    int scheduleContrib = 0;
    String scheduleStatus = 'EVALUATED';
    String scheduleDetails;
    final hour = artTime.hour;
    final minute = artTime.minute;
    final totalMinutes = hour * 60 + minute;

    // Madrugada: 03:00 a 06:00
    if (totalMinutes >= 3 * 60 && totalMinutes < 6 * 60) {
      scheduleContrib = weightScheduleNight;
      scheduleDetails = 'Horario de madrugada (03:00 - 06:00 ART)';
    } else if (totalMinutes >= 8 * 60 && totalMinutes < 14 * 60) {
      scheduleContrib = weightScheduleSchool;
      scheduleDetails = 'Horario escolar (08:00 - 14:00 ART)';
    } else {
      scheduleContrib = 0;
      scheduleDetails = 'Horario habitual ($hour:${minute.toString().padLeft(2, '0')} ART)';
    }
    details.add({
      'factorName': 'SCHEDULE',
      'contribution': scheduleContrib,
      'maxWeight': max(weightScheduleNight, weightScheduleSchool),
      'status': scheduleStatus,
      'details': scheduleDetails,
    });
    factorContributions['schedule'] = scheduleContrib;
    factorStatus['schedule'] = scheduleStatus;

    // 6. RIESGO DE RED / VPN / PROXY (CU-0032)
    int networkContrib = 0;
    String networkStatus;
    String networkDetails;
    if (input.clientVpnDetected == true || input.clientProxyDetected == true) {
      networkContrib = weightNetworkClientUntrusted;
      networkStatus = 'CLIENT_UNTRUSTED_SIGNAL';
      networkDetails = 'Señal no confiable de cliente: VPN o proxy reportado (+ $weightNetworkClientUntrusted)';
    } else {
      if (missingPolicyNetwork.toUpperCase() == 'PENALIZE') {
        networkContrib = missingPenaltyNetwork;
        networkStatus = 'MISSING_PENALIZED';
        networkDetails = 'Señal de red ausente (penalizado)';
      } else {
        networkContrib = 0;
        networkStatus = 'MISSING_IGNORED';
        networkDetails = 'Sin anomalías de red detectadas';
      }
    }
    details.add({
      'factorName': 'NETWORK_RISK',
      'contribution': networkContrib,
      'maxWeight': weightNetworkHigh,
      'status': networkStatus,
      'details': networkDetails,
    });
    factorContributions['networkRisk'] = networkContrib;
    factorStatus['networkRisk'] = networkStatus;

    // 7. COMPORTAMIENTO DE INTERFAZ (CU-0035)
    int behaviorContrib = 0;
    String behaviorStatus;
    String behaviorDetails;
    if (input.behavioralAdultScore != null) {
      if (input.behavioralAdultScore! < thresholdBehaviorAdultMin) {
        behaviorContrib = weightBehaviorLowAdult;
        behaviorDetails = 'Score adulto bajo (${input.behavioralAdultScore!.toStringAsFixed(2)} < $thresholdBehaviorAdultMin). Contribución complementaria (+ $weightBehaviorLowAdult)';
      } else {
        behaviorContrib = 0;
        behaviorDetails = 'Score adulto normal (${input.behavioralAdultScore!.toStringAsFixed(2)})';
      }
      behaviorStatus = 'EVALUATED';
    } else {
      if (missingPolicyBehavior.toUpperCase() == 'PENALIZE') {
        behaviorContrib = missingPenaltyBehavior;
        behaviorStatus = 'MISSING_PENALIZED';
        behaviorDetails = 'Señal de comportamiento ausente (penalizado)';
      } else {
        behaviorContrib = 0;
        behaviorStatus = 'MISSING_IGNORED';
        behaviorDetails = 'Señal de comportamiento no provista (ignorado por política)';
      }
    }
    details.add({
      'factorName': 'BEHAVIORAL_BIOMETRICS',
      'contribution': behaviorContrib,
      'maxWeight': weightBehaviorLowAdult,
      'status': behaviorStatus,
      'details': behaviorDetails,
    });
    factorContributions['behavioral'] = behaviorContrib;
    factorStatus['behavioral'] = behaviorStatus;

    // 8. REINTENTOS FACIALES FALLIDOS RECIENTES (CU-0016)
    int facialAttemptsContrib = 0;
    String facialAttemptsStatus;
    String facialAttemptsDetails;
    if (input.failedFaceAttempts != null && input.failedFaceAttempts! > 0) {
      facialAttemptsContrib = min(60, input.failedFaceAttempts! * weightFacialFailedAttempts);
      facialAttemptsStatus = 'EVALUATED';
      facialAttemptsDetails = 'Reintentos fallidos recientes de liveness/facial detectados: ${input.failedFaceAttempts} (+ $facialAttemptsContrib puntos)';
    } else {
      facialAttemptsContrib = 0;
      facialAttemptsStatus = 'NONE';
      facialAttemptsDetails = 'Sin reintentos fallidos previos en la sesión';
    }
    details.add({
      'factorName': 'FACIAL_FAILED_ATTEMPTS',
      'contribution': facialAttemptsContrib,
      'maxWeight': 60,
      'status': facialAttemptsStatus,
      'details': facialAttemptsDetails,
    });
    factorContributions['facialFailedAttempts'] = facialAttemptsContrib;
    factorStatus['facialFailedAttempts'] = facialAttemptsStatus;

    // TOTAL NORMALIZADO [0 - 100]
    final rawScore = livenessContrib +
        faceMatchContrib +
        docContrib +
        scheduleContrib +
        networkContrib +
        behaviorContrib +
        facialAttemptsContrib;

    final compositeScore = rawScore.clamp(0, 100);

    LocalRiskDecision decision;
    if (compositeScore >= blockThreshold) {
      decision = LocalRiskDecision.BLOQUEAR;
    } else if (compositeScore >= reviewThreshold) {
      decision = LocalRiskDecision.REVISION;
    } else {
      decision = LocalRiskDecision.AUTORIZAR;
    }

    return LocalRiskBreakdown(
      compositeScore: compositeScore,
      decision: decision,
      hardRuleApplied: null,
      factorContributions: factorContributions,
      factorStatus: factorStatus,
      details: details,
      evaluatedAt: now,
    );
  }
}
