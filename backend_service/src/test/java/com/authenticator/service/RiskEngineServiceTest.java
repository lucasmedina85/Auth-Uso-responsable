package com.authenticator.service;

import com.authenticator.domain.RiskDecision;
import com.authenticator.domain.RiskScoreBreakdown;
import com.authenticator.domain.VerificationResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.LocalTime;

import static org.junit.jupiter.api.Assertions.assertEquals;

class RiskEngineServiceTest {

    private RiskEngineService riskEngineService;

    @BeforeEach
    void setUp() {
        riskEngineService = new RiskEngineService();
        ReflectionTestUtils.setField(riskEngineService, "riskThreshold", 80);
    }

    @Test
    void testLegitimateUser_shouldAuthorize() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // Penalty = 5
        result.setLivenessScore(98);    // Penalty = 2
        result.setIsLatestDocument(true); // Penalty = 0

        // Horario normal (fuera de madrugada y escolar)
        LocalTime normalTime = LocalTime.of(15, 0); 
        
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(7, score);
        assertEquals("AUTORIZAR", riskScoreToDecision(score));
    }

    @Test
    void testSuspiciousUser_shouldBlock() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(50);   // Penalty = 50
        result.setLivenessScore(60);    // Penalty = 40
        result.setIsLatestDocument(true); // Penalty = 0

        LocalTime suspiciousTime = LocalTime.of(4, 0); // +20
        
        int score = riskEngineService.calculateRiskScore(result, suspiciousTime);
        assertEquals(100, score); // Capped at 100
        
        assertEquals("BLOQUEAR", riskScoreToDecision(score));
    }
    
    @Test
    void testUnknownDocument_shouldNotPenalize() {
        // En escenarios donde la política documental se configura explícitamente en IGNORE
        // (por ejemplo si la vigencia fue delegada a un validador externo previo), no debe penalizar.
        ReflectionTestUtils.setField(riskEngineService, "missingPolicyDocument", "IGNORE");

        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(100);   
        result.setLivenessScore(100);    
        result.setIsLatestDocument(null); // UNKNOWN -> Penalty = 0 con política IGNORE

        LocalTime normalTime = LocalTime.of(15, 0); 
        
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(0, score);
    }

    @Test
    void testDefaultMissingSignals_documentMissing_penalizesToRevision() {
        // Con la política por defecto (PENALIZE), omitir isLatestDocument aporta 50 puntos y lleva a REVISIÓN
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(100);   
        result.setLivenessScore(100);    
        result.setIsLatestDocument(null); 

        LocalTime normalTime = LocalTime.of(15, 0); 
        
        RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(result, normalTime);
        assertEquals(50, breakdown.getCompositeScore());
        assertEquals(RiskDecision.REVISIÓN, breakdown.getDecision());
    }

    @Test
    void testOmissionOfAllThreeCriticalSignals_neverAuthorizes() {
        // CU-0023 Ajuste 1: Si un cliente manipulado omite livenessScore, faceMatchScore e isLatestDocument,
        // NUNCA debe autorizar. Con política PENALIZE satura en 100 puntos y BLOQUEA.
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(null);
        result.setLivenessScore(null);
        result.setIsLatestDocument(null);

        LocalTime normalTime = LocalTime.of(15, 0); 
        
        RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(result, normalTime);
        assertEquals(100, breakdown.getCompositeScore());
        assertEquals(RiskDecision.BLOQUEAR, breakdown.getDecision());
    }

    @Test
    void testDecisionBoundaries_exactThresholds() {
        // Umbral de revisión = 50, Umbral de bloqueo = 80
        VerificationResult result = new VerificationResult();
        result.setIsLatestDocument(true);

        // Score 0 -> AUTORIZAR
        result.setLivenessScore(100);
        result.setFaceMatchScore(100);
        assertEquals(RiskDecision.AUTORIZAR, riskEngineService.evaluateRiskDetailed(result, LocalTime.of(15, 0)).getDecision());

        // Score 49 -> AUTORIZAR
        // Con livenessScore=51 -> penalidad (100-51) = 49
        result.setLivenessScore(51);
        result.setFaceMatchScore(100);
        RiskScoreBreakdown b49 = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(15, 0));
        assertEquals(49, b49.getCompositeScore());
        assertEquals(RiskDecision.AUTORIZAR, b49.getDecision());

        // Score 50 -> REVISIÓN (límite inferior inclusivo)
        result.setLivenessScore(50);
        result.setFaceMatchScore(100);
        RiskScoreBreakdown b50 = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(15, 0));
        assertEquals(50, b50.getCompositeScore());
        assertEquals(RiskDecision.REVISIÓN, b50.getDecision());

        // Score 79 -> REVISIÓN (límite superior de revisión)
        result.setLivenessScore(21); // 79 puntos
        result.setFaceMatchScore(100);
        RiskScoreBreakdown b79 = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(15, 0));
        assertEquals(79, b79.getCompositeScore());
        assertEquals(RiskDecision.REVISIÓN, b79.getDecision());

        // Score 80 -> BLOQUEAR (límite inferior de bloqueo)
        result.setLivenessScore(20); // 80 puntos
        result.setFaceMatchScore(100);
        RiskScoreBreakdown b80 = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(15, 0));
        assertEquals(80, b80.getCompositeScore());
        assertEquals(RiskDecision.BLOQUEAR, b80.getDecision());
    }

    @Test
    void testScheduleEvaluation_nightAndSchoolHours() {
        VerificationResult result = new VerificationResult();
        result.setLivenessScore(100);
        result.setFaceMatchScore(100);
        result.setIsLatestDocument(true);

        // Madrugada (03:30) -> +20
        RiskScoreBreakdown night = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(3, 30));
        assertEquals(20, night.getCompositeScore());
        assertEquals(20, night.getFactorContributions().get("schedule"));

        // Horario escolar mañana (09:15) -> +10
        RiskScoreBreakdown schoolMorning = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(9, 15));
        assertEquals(10, schoolMorning.getCompositeScore());
        assertEquals(10, schoolMorning.getFactorContributions().get("schedule"));

        // Horario escolar (11:30) -> +10
        RiskScoreBreakdown schoolAfternoon = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(11, 30));
        assertEquals(10, schoolAfternoon.getCompositeScore());
        assertEquals(10, schoolAfternoon.getFactorContributions().get("schedule"));

        // Horario normal (19:00) -> 0
        RiskScoreBreakdown evening = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(19, 0));
        assertEquals(0, evening.getCompositeScore());
        assertEquals(0, night.getFactorContributions().getOrDefault("schedule_normal", 0));
    }

    @Test
    void testNetworkRiskMedium_adds15Points() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(100);
        result.setLivenessScore(100);
        result.setIsLatestDocument(true);
        result.setNetworkRiskLevel(com.authenticator.domain.NetworkRiskLevel.MEDIO);

        RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(19, 0));
        assertEquals(15, breakdown.getCompositeScore());
        assertEquals(15, breakdown.getFactorContributions().get("networkRisk"));
    }

    @Test
    void testBiometricProportionalFormulas() {
        VerificationResult result = new VerificationResult();
        result.setIsLatestDocument(true);
        // livenessScore 75% -> (100 - 75) * 100 / 100 = 25
        result.setLivenessScore(75);
        // faceMatchScore 80% -> (100 - 80) * 100 / 100 = 20
        result.setFaceMatchScore(80);

        RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(result, LocalTime.of(19, 0));
        assertEquals(45, breakdown.getCompositeScore());
        assertEquals(25, breakdown.getFactorContributions().get("liveness"));
        assertEquals(20, breakdown.getFactorContributions().get("faceMatch"));
    }

    @Test
    void testClockEvaluation_inBuenosAiresTimezone() {
        // Prueba con Clock inyectado en zona Buenos Aires
        java.time.Instant instantNight = java.time.Instant.parse("2026-10-13T06:30:00Z"); // 03:30 ART (UTC-3)
        java.time.Clock fixedClock = java.time.Clock.fixed(instantNight, java.time.ZoneId.of("America/Argentina/Buenos_Aires"));

        RiskEngineService clockService = new RiskEngineService(fixedClock);

        VerificationResult result = new VerificationResult();
        result.setLivenessScore(100);
        result.setFaceMatchScore(100);
        result.setIsLatestDocument(true);

        RiskScoreBreakdown breakdown = clockService.evaluateRiskDetailed(result);
        assertEquals(20, breakdown.getCompositeScore());
        assertEquals(20, breakdown.getFactorContributions().get("schedule"));
    }

    @Test
    void testEmulatorDetected_shouldBlockHardRule() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(100);
        result.setLivenessScore(100);
        result.setIsLatestDocument(true);
        result.setEmulatorDetected(true);

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(100, score);
        assertEquals("BLOQUEAR", riskEngineService.evaluateRisk(result));
    }

    @Test
    void testNetworkRiskAlto_adds30Points() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // 5
        result.setLivenessScore(98);    // 2
        result.setIsLatestDocument(true);
        result.setNetworkRiskLevel(com.authenticator.domain.NetworkRiskLevel.ALTO); // +30

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(37, score);
    }

    @Test
    void testUntrustedClientSignalOnly_adds5Points() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // 5
        result.setLivenessScore(98);    // 2
        result.setIsLatestDocument(true);
        result.setClientVpnDetected(true); // Untrusted client signal -> +5

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(12, score);
    }

    @Test
    void testBehavioralAdultScore_lowScoreAdds10PointsComplementary() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // 5
        result.setLivenessScore(98);    // 2
        result.setIsLatestDocument(true);
        result.setBehavioralAdultScore(0.25); // Low adult score (<0.35) -> complementary +10

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(17, score);
        // CU-0035 Requirement: Untrusted complementary signal NEVER causes a unilateral block by itself
        assertEquals("AUTORIZAR", riskScoreToDecision(score));
    }

    @Test
    void testBehavioralAdultScore_normalOrHighAdds0Points() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // 5
        result.setLivenessScore(98);    // 2
        result.setIsLatestDocument(true);
        result.setBehavioralAdultScore(0.85); // High adult score -> +0

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(7, score);
    }

    @Test
    void testBehavioralAdultScore_nullPreservesExistingBehavior() {
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(95);   // 5
        result.setLivenessScore(98);    // 2
        result.setIsLatestDocument(true);
        result.setBehavioralAdultScore(null); // Absent -> +0

        LocalTime normalTime = LocalTime.of(15, 0);
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(7, score);
    }

    private String riskScoreToDecision(int score) {
        return score >= 80 ? "BLOQUEAR" : "AUTORIZAR";
    }
}
