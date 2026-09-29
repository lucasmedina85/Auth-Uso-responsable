package com.authenticator.service;

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
        VerificationResult result = new VerificationResult();
        result.setFaceMatchScore(100);   
        result.setLivenessScore(100);    
        result.setIsLatestDocument(null); // UNKNOWN -> Penalty = 0

        LocalTime normalTime = LocalTime.of(15, 0); 
        
        int score = riskEngineService.calculateRiskScore(result, normalTime);
        assertEquals(0, score);
    }

    private String riskScoreToDecision(int score) {
        return score >= 80 ? "BLOQUEAR" : "AUTORIZAR";
    }
}
