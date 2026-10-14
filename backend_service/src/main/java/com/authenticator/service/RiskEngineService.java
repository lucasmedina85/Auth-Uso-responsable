package com.authenticator.service;

import com.authenticator.domain.NetworkRiskLevel;
import com.authenticator.domain.RiskDecision;
import com.authenticator.domain.RiskFactorBreakdown;
import com.authenticator.domain.RiskScoreBreakdown;
import com.authenticator.domain.VerificationResult;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Motor de Riesgo (Risk Score Compuesto) - CU-0023
 *
 * Integra biometría (liveness y coincidencia facial), vigencia documental,
 * horario de solicitud (zona horaria configurable), detección de emuladores (regla dura),
 * análisis de red (VPN/proxies autoritativo vs cliente) y dinámicas de comportamiento táctil.
 *
 * Jerarquía de evidencia:
 * - Reglas duras (emulador) -> BLOQUEAR inmediato sin ponderación.
 * - Evidencia verificada por backend (IP, horario) -> Alto peso probatorio.
 * - Señales no confiables de cliente (VPN cliente, biometría comportamental) -> Peso complementario bajo.
 *   El comportamiento de interfaz NUNCA bloquea por sí solo.
 */
@Service
public class RiskEngineService {

    private static final Logger logger = LoggerFactory.getLogger(RiskEngineService.class);

    @Value("${app.risk.timezone:America/Argentina/Buenos_Aires}")
    private String timezoneString = "America/Argentina/Buenos_Aires";

    @Value("${app.risk.thresholds.review:50}")
    private int reviewThreshold = 50;

    @Value("${app.risk.thresholds.block:${app.thresholds.risk:80}}")
    private int blockThreshold = 80;

    // Campo de compatibilidad para tests existentes que invocan ReflectionTestUtils.setField(..., "riskThreshold", ...)
    private Integer riskThreshold;

    @Value("${app.risk.weights.liveness:100}")
    private int weightLiveness = 100;

    @Value("${app.risk.weights.face-match:100}")
    private int weightFaceMatch = 100;

    @Value("${app.risk.weights.document-not-latest:50}")
    private int weightDocumentNotLatest = 50;

    @Value("${app.risk.weights.schedule-night:20}")
    private int weightScheduleNight = 20;

    @Value("${app.risk.weights.schedule-school:10}")
    private int weightScheduleSchool = 10;

    @Value("${app.risk.weights.network-high:30}")
    private int weightNetworkHigh = 30;

    @Value("${app.risk.weights.network-medium:15}")
    private int weightNetworkMedium = 15;

    @Value("${app.risk.weights.network-client-untrusted:5}")
    private int weightNetworkClientUntrusted = 5;

    @Value("${app.risk.weights.behavior-low-adult:10}")
    private int weightBehaviorLowAdult = 10;

    @Value("${app.risk.weights.facial-failed-attempts:15}")
    private int weightFacialFailedAttempts = 15;

    @Value("${app.risk.thresholds-behavior.adult-min:0.35}")
    private double thresholdBehaviorAdultMin = 0.35;

    // Políticas de señales faltantes: PENALIZE para señales críticas de cliente; IGNORE para opcionales
    @Value("${app.risk.missing-policy.liveness:PENALIZE}")
    private String missingPolicyLiveness = "PENALIZE";

    @Value("${app.risk.missing-policy.face-match:PENALIZE}")
    private String missingPolicyFaceMatch = "PENALIZE";

    @Value("${app.risk.missing-policy.document:PENALIZE}")
    private String missingPolicyDocument = "PENALIZE";

    @Value("${app.risk.missing-policy.network:IGNORE}")
    private String missingPolicyNetwork = "IGNORE";

    @Value("${app.risk.missing-policy.behavior:IGNORE}")
    private String missingPolicyBehavior = "IGNORE";

    // Penalizaciones configurables por omisión
    @Value("${app.risk.missing-penalties.liveness:50}")
    private int missingPenaltyLiveness = 50;

    @Value("${app.risk.missing-penalties.face-match:50}")
    private int missingPenaltyFaceMatch = 50;

    @Value("${app.risk.missing-penalties.document:50}")
    private int missingPenaltyDocument = 50;

    @Value("${app.risk.missing-penalties.network:10}")
    private int missingPenaltyNetwork = 10;

    @Value("${app.risk.missing-penalties.behavior:10}")
    private int missingPenaltyBehavior = 10;

    private final Clock clock;

    public RiskEngineService(@Autowired(required = false) Clock clock) {
        if (clock != null) {
            this.clock = clock;
        } else {
            this.clock = Clock.system(ZoneId.of("America/Argentina/Buenos_Aires"));
        }
    }

    public RiskEngineService() {
        this.clock = Clock.system(ZoneId.of("America/Argentina/Buenos_Aires"));
    }

    private int getEffectiveBlockThreshold() {
        return this.riskThreshold != null ? this.riskThreshold : this.blockThreshold;
    }

    /**
     * Evalúa el riesgo y retorna la decisión canónica en formato String para compatibilidad.
     */
    public String evaluateRisk(VerificationResult verificationResult) {
        RiskScoreBreakdown breakdown = evaluateRiskDetailed(verificationResult);
        return breakdown.getDecision().name();
    }

    /**
     * Calcula el score compuesto para un horario determinado (usado por tests y pipelines).
     */
    public int calculateRiskScore(VerificationResult verificationResult, LocalTime currentTime) {
        RiskScoreBreakdown breakdown = evaluateRiskDetailed(verificationResult, currentTime);
        return breakdown.getCompositeScore();
    }

    /**
     * Evaluación detallada de riesgo usando el reloj inyectado y la zona horaria configurada.
     */
    public RiskScoreBreakdown evaluateRiskDetailed(VerificationResult verificationResult) {
        ZoneId zoneId = ZoneId.of(timezoneString);
        LocalTime currentTime = LocalTime.now(clock.withZone(zoneId));
        return evaluateRiskDetailed(verificationResult, currentTime);
    }

    /**
     * Evaluación detallada de riesgo pasando explícitamente el horario de análisis.
     */
    public RiskScoreBreakdown evaluateRiskDetailed(VerificationResult verificationResult, LocalTime currentTime) {
        List<RiskFactorBreakdown> details = new ArrayList<>();
        Map<String, Integer> factorContributions = new LinkedHashMap<>();
        Map<String, String> factorStatus = new LinkedHashMap<>();

        // 1. REGLA DURA: Integridad de dispositivo (Emulador CU-0034 / Root-Jailbreak CU-0033)
        boolean isDeviceCompromised = Boolean.TRUE.equals(verificationResult.getEmulatorDetected())
                || Boolean.TRUE.equals(verificationResult.getDeviceCompromised());

        if (isDeviceCompromised) {
            String ruleReason = Boolean.TRUE.equals(verificationResult.getEmulatorDetected())
                    ? "EMULATOR_DETECTED"
                    : "DEVICE_COMPROMISED";
            String detailsText = Boolean.TRUE.equals(verificationResult.getEmulatorDetected())
                    ? "Emulador detectado en entorno de ejecución (regla dura CU-0034)"
                    : "Dispositivo comprometido / root detectado (regla dura CU-0033)";

            RiskFactorBreakdown emuFactor = RiskFactorBreakdown.builder()
                    .factorName("DEVICE_INTEGRITY")
                    .contribution(100)
                    .maxWeight(100)
                    .status("HARD_RULE_TRIGGERED")
                    .details(detailsText)
                    .build();
            details.add(emuFactor);
            factorContributions.put("device_integrity", 100);
            factorStatus.put("device_integrity", "HARD_RULE_TRIGGERED");

            RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                    .compositeScore(100)
                    .decision(RiskDecision.BLOQUEAR)
                    .hardRuleApplied(ruleReason)
                    .factorContributions(factorContributions)
                    .factorStatus(factorStatus)
                    .details(details)
                    .evaluatedAt(LocalDateTime.now(clock))
                    .build();

            verificationResult.setCompositeRiskScore(100);
            verificationResult.setRiskDecision(RiskDecision.BLOQUEAR);
            verificationResult.setRiskBreakdown(breakdown);

            logger.warn("Bloqueo duro ejecutado por integridad de dispositivo ({}) (CU-0033/CU-0034). Score: 100", ruleReason);
            return breakdown;
        }

        if (Boolean.TRUE.equals(verificationResult.getDniBlacklisted())) {
            RiskFactorBreakdown blFactor = RiskFactorBreakdown.builder()
                    .factorName("DNI_BLACKLISTED")
                    .contribution(100)
                    .maxWeight(100)
                    .status("HARD_RULE_TRIGGERED")
                    .details("DNI presente en lista negra de fraude (regla dura CU-0043)")
                    .build();
            details.add(blFactor);
            factorContributions.put("dni_blacklist", 100);
            factorStatus.put("dni_blacklist", "HARD_RULE_TRIGGERED");

            RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                    .compositeScore(100)
                    .decision(RiskDecision.BLOQUEAR)
                    .hardRuleApplied("DNI_BLACKLISTED")
                    .factorContributions(factorContributions)
                    .factorStatus(factorStatus)
                    .details(details)
                    .evaluatedAt(LocalDateTime.now(clock))
                    .build();

            verificationResult.setCompositeRiskScore(100);
            verificationResult.setRiskDecision(RiskDecision.BLOQUEAR);
            verificationResult.setRiskBreakdown(breakdown);

            logger.warn("Bloqueo duro ejecutado por DNI en lista negra (CU-0043). Score: 100");
            return breakdown;
        }

        if (Boolean.TRUE.equals(verificationResult.getUserLockedOut())) {
            RiskFactorBreakdown lockFactor = RiskFactorBreakdown.builder()
                    .factorName("USER_LOCKED_OUT")
                    .contribution(100)
                    .maxWeight(100)
                    .status("HARD_RULE_TRIGGERED")
                    .details("Usuario con bloqueo de seguridad temporal activo (regla dura CU-0045)")
                    .build();
            details.add(lockFactor);
            factorContributions.put("user_lockout", 100);
            factorStatus.put("user_lockout", "HARD_RULE_TRIGGERED");

            RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                    .compositeScore(100)
                    .decision(RiskDecision.BLOQUEAR)
                    .hardRuleApplied("USER_LOCKED_OUT")
                    .factorContributions(factorContributions)
                    .factorStatus(factorStatus)
                    .details(details)
                    .evaluatedAt(LocalDateTime.now(clock))
                    .build();

            verificationResult.setCompositeRiskScore(100);
            verificationResult.setRiskDecision(RiskDecision.BLOQUEAR);
            verificationResult.setRiskBreakdown(breakdown);

            logger.warn("Bloqueo duro ejecutado por usuario bloqueado (CU-0045). Score: 100");
            return breakdown;
        }

        // 2. BIOMETRÍA: Liveness Score (CU-0014)
        int livenessContrib = 0;
        String livenessStatus;
        String livenessDetails;
        if (verificationResult.getLivenessScore() != null) {
            int score = Math.max(0, Math.min(100, verificationResult.getLivenessScore()));
            livenessContrib = (int) Math.round(((100.0 - score) / 100.0) * weightLiveness);
            livenessStatus = "EVALUATED";
            livenessDetails = String.format("Score liveness: %d / 100 (contribución: %d, máx: %d)", score, livenessContrib, weightLiveness);
        } else {
            if ("PENALIZE".equalsIgnoreCase(missingPolicyLiveness)) {
                livenessContrib = missingPenaltyLiveness;
                livenessStatus = "MISSING_PENALIZED";
                livenessDetails = "Liveness no provisto (penalizado por omisión de señal crítica)";
            } else {
                livenessContrib = 0;
                livenessStatus = "MISSING_IGNORED";
                livenessDetails = "Liveness no provisto (ignorado por política)";
            }
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("LIVENESS")
                .contribution(livenessContrib)
                .maxWeight(weightLiveness)
                .status(livenessStatus)
                .details(livenessDetails)
                .build());
        factorContributions.put("liveness", livenessContrib);
        factorStatus.put("liveness", livenessStatus);

        // 3. BIOMETRÍA: Face Match Score (CU-0015)
        int faceMatchContrib = 0;
        String faceMatchStatus;
        String faceMatchDetails;
        if (verificationResult.getFaceMatchScore() != null) {
            int score = Math.max(0, Math.min(100, verificationResult.getFaceMatchScore()));
            faceMatchContrib = (int) Math.round(((100.0 - score) / 100.0) * weightFaceMatch);
            faceMatchStatus = "EVALUATED";
            faceMatchDetails = String.format("Score cotejo facial: %d / 100 (contribución: %d, máx: %d)", score, faceMatchContrib, weightFaceMatch);
        } else {
            if ("PENALIZE".equalsIgnoreCase(missingPolicyFaceMatch)) {
                faceMatchContrib = missingPenaltyFaceMatch;
                faceMatchStatus = "MISSING_PENALIZED";
                faceMatchDetails = "Cotejo facial no provisto (penalizado por omisión de señal crítica)";
            } else {
                faceMatchContrib = 0;
                faceMatchStatus = "MISSING_IGNORED";
                faceMatchDetails = "Cotejo facial no provisto (ignorado por política)";
            }
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("FACE_MATCH")
                .contribution(faceMatchContrib)
                .maxWeight(weightFaceMatch)
                .status(faceMatchStatus)
                .details(faceMatchDetails)
                .build());
        factorContributions.put("faceMatch", faceMatchContrib);
        factorStatus.put("faceMatch", faceMatchStatus);

        // 4. VIGENCIA DOCUMENTAL: Tri-estado (CU-0009)
        int docContrib = 0;
        String docStatus;
        String docDetails;
        Boolean isLatest = verificationResult.getIsLatestDocument();
        if (Boolean.FALSE.equals(isLatest)) {
            docContrib = weightDocumentNotLatest;
            docStatus = "EVALUATED";
            docDetails = "Documento no vigente o desactualizado";
        } else if (Boolean.TRUE.equals(isLatest)) {
            docContrib = 0;
            docStatus = "EVALUATED";
            docDetails = "Documento vigente y confirmado";
        } else {
            if ("PENALIZE".equalsIgnoreCase(missingPolicyDocument)) {
                docContrib = missingPenaltyDocument;
                docStatus = "MISSING_PENALIZED";
                docDetails = "Vigencia de documento no provista (penalizado por omisión de señal crítica)";
            } else {
                docContrib = 0;
                docStatus = "MISSING_IGNORED";
                docDetails = "Vigencia de documento desconocida o delegada (no punible)";
            }
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("DOCUMENT_VALIDITY")
                .contribution(docContrib)
                .maxWeight(weightDocumentNotLatest)
                .status(docStatus)
                .details(docDetails)
                .build());
        factorContributions.put("documentValidity", docContrib);
        factorStatus.put("documentValidity", docStatus);

        // 5. HORARIO DE SOLICITUD (CU-0022)
        int scheduleContrib = 0;
        String scheduleStatus = "EVALUATED";
        String scheduleDetails;
        if (currentTime.isAfter(LocalTime.of(3, 0)) && currentTime.isBefore(LocalTime.of(6, 0))) {
            scheduleContrib = weightScheduleNight;
            scheduleDetails = "Horario de madrugada (03:00 - 06:00 ART)";
        } else if (currentTime.isAfter(LocalTime.of(8, 0)) && currentTime.isBefore(LocalTime.of(14, 0))) {
            scheduleContrib = weightScheduleSchool;
            scheduleDetails = "Horario escolar (08:00 - 14:00 ART)";
        } else {
            scheduleContrib = 0;
            scheduleDetails = "Horario habitual (" + currentTime.toString() + " ART)";
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("SCHEDULE")
                .contribution(scheduleContrib)
                .maxWeight(Math.max(weightScheduleNight, weightScheduleSchool))
                .status(scheduleStatus)
                .details(scheduleDetails)
                .build());
        factorContributions.put("schedule", scheduleContrib);
        factorStatus.put("schedule", scheduleStatus);

        // 6. RIESGO DE RED / VPN / PROXY (CU-0032)
        int networkContrib = 0;
        String networkStatus;
        String networkDetails;
        NetworkRiskLevel netLevel = verificationResult.getNetworkRiskLevel();
        if (netLevel != null) {
            if (netLevel == NetworkRiskLevel.ALTO) {
                networkContrib = weightNetworkHigh;
                networkDetails = "Riesgo de red verificado por backend: ALTO (+ " + weightNetworkHigh + ")";
            } else if (netLevel == NetworkRiskLevel.MEDIO) {
                networkContrib = weightNetworkMedium;
                networkDetails = "Riesgo de red verificado por backend: MEDIO (+ " + weightNetworkMedium + ")";
            } else {
                networkContrib = 0;
                networkDetails = "Riesgo de red verificado por backend: BAJO (0)";
            }
            networkStatus = "EVALUATED";
        } else if (Boolean.TRUE.equals(verificationResult.getClientVpnDetected()) || Boolean.TRUE.equals(verificationResult.getClientProxyDetected())) {
            networkContrib = weightNetworkClientUntrusted;
            networkStatus = "CLIENT_UNTRUSTED_SIGNAL";
            networkDetails = "Señal no confiable de cliente: VPN o proxy reportado sin confirmación de IP (+ " + weightNetworkClientUntrusted + ")";
        } else {
            if ("PENALIZE".equalsIgnoreCase(missingPolicyNetwork)) {
                networkContrib = missingPenaltyNetwork;
                networkStatus = "MISSING_PENALIZED";
                networkDetails = "Señal de red ausente (penalizado)";
            } else {
                networkContrib = 0;
                networkStatus = "MISSING_IGNORED";
                networkDetails = "Sin anomalías de red detectadas";
            }
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("NETWORK_RISK")
                .contribution(networkContrib)
                .maxWeight(weightNetworkHigh)
                .status(networkStatus)
                .details(networkDetails)
                .build());
        factorContributions.put("networkRisk", networkContrib);
        factorStatus.put("networkRisk", networkStatus);

        // 7. COMPORTAMIENTO DE INTERFAZ (CU-0035)
        int behaviorContrib = 0;
        String behaviorStatus;
        String behaviorDetails;
        Double adultScore = verificationResult.getBehavioralAdultScore();
        if (adultScore != null) {
            if (adultScore < thresholdBehaviorAdultMin) {
                behaviorContrib = weightBehaviorLowAdult;
                behaviorDetails = String.format("Score adulto bajo (%.2f < %.2f). Contribución complementaria (+ %d)", adultScore, thresholdBehaviorAdultMin, weightBehaviorLowAdult);
            } else {
                behaviorContrib = 0;
                behaviorDetails = String.format("Score adulto normal (%.2f)", adultScore);
            }
            behaviorStatus = "EVALUATED";
        } else {
            if ("PENALIZE".equalsIgnoreCase(missingPolicyBehavior)) {
                behaviorContrib = missingPenaltyBehavior;
                behaviorStatus = "MISSING_PENALIZED";
                behaviorDetails = "Señal de comportamiento ausente (penalizado)";
            } else {
                behaviorContrib = 0;
                behaviorStatus = "MISSING_IGNORED";
                behaviorDetails = "Señal de comportamiento no provista (ignorado por política)";
            }
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("BEHAVIORAL_BIOMETRICS")
                .contribution(behaviorContrib)
                .maxWeight(weightBehaviorLowAdult)
                .status(behaviorStatus)
                .details(behaviorDetails)
                .build());
        factorContributions.put("behavioral", behaviorContrib);
        factorStatus.put("behavioral", behaviorStatus);

        // 8. REINTENTOS FACIALES FALLIDOS RECIENTES (CU-0016)
        int facialAttemptsContrib = 0;
        String facialAttemptsStatus;
        String facialAttemptsDetails;
        Integer failedAttempts = verificationResult.getFailedFaceAttempts();
        if (failedAttempts != null && failedAttempts > 0) {
            facialAttemptsContrib = Math.min(60, failedAttempts * weightFacialFailedAttempts);
            facialAttemptsStatus = "EVALUATED";
            facialAttemptsDetails = String.format("Reintentos fallidos recientes de liveness/facial detectados: %d (+ %d puntos de penalización)", failedAttempts, facialAttemptsContrib);
        } else {
            facialAttemptsContrib = 0;
            facialAttemptsStatus = "NONE";
            facialAttemptsDetails = "Sin reintentos fallidos previos en la sesión";
        }
        details.add(RiskFactorBreakdown.builder()
                .factorName("FACIAL_FAILED_ATTEMPTS")
                .contribution(facialAttemptsContrib)
                .maxWeight(60)
                .status(facialAttemptsStatus)
                .details(facialAttemptsDetails)
                .build());
        factorContributions.put("facialFailedAttempts", facialAttemptsContrib);
        factorStatus.put("facialFailedAttempts", facialAttemptsStatus);

        // TOTAL NORMALIZADO (0 - 100)
        int rawScore = livenessContrib + faceMatchContrib + docContrib + scheduleContrib + networkContrib + behaviorContrib + facialAttemptsContrib;
        int compositeScore = Math.min(100, Math.max(0, rawScore));

        // DECISIÓN BASADA EN UMBRALES
        RiskDecision decision;
        if (compositeScore >= getEffectiveBlockThreshold()) {
            decision = RiskDecision.BLOQUEAR;
        } else if (compositeScore >= reviewThreshold) {
            decision = RiskDecision.REVISIÓN;
        } else {
            decision = RiskDecision.AUTORIZAR;
        }

        RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                .compositeScore(compositeScore)
                .decision(decision)
                .hardRuleApplied(null)
                .factorContributions(factorContributions)
                .factorStatus(factorStatus)
                .details(details)
                .evaluatedAt(LocalDateTime.now(clock))
                .build();

        verificationResult.setCompositeRiskScore(compositeScore);
        verificationResult.setRiskDecision(decision);
        verificationResult.setRiskBreakdown(breakdown);

        logger.info("Evaluación de riesgo completada - Score: {}, Decisión: {}, Aportes: {}",
                compositeScore, decision, factorContributions);

        return breakdown;
    }
}
