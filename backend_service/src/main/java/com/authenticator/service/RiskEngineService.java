package com.authenticator.service;

import com.authenticator.domain.VerificationResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;

@Service
public class RiskEngineService {

    @Value("${app.thresholds.risk:80}")
    private int riskThreshold;

    /**
     * Motor de Riesgo (Risk Score) - CU-0023
     * 
     * Calcula el nivel de riesgo de la verificación actual. A mayor valor, mayor riesgo.
     * Si el score iguala o supera el RISK_THRESHOLD, la operación se bloquea.
     * 
     * Tabla de pesos:
     * - Liveness Score (CU-0014): 100 - Score (ej. 98 -> 2 ptos de riesgo)
     * - Face Match Score (CU-0015): 100 - Score (ej. 95 -> 5 ptos de riesgo)
     * - Documento no vigente (CU-0009 fallido): 50 ptos. Si es UNKNOWN (null) suma 0 ptos (delegado/no punible).
     * - Horario Sospechoso (CU-0022): 20 ptos (De 03:00 a 06:00, hora Argentina)
     * - Horario Escolar (CU-0022): 10 ptos (De 08:00 a 14:00, hora Argentina)
     * 
     * Caso Legítimo "7":
     * - Liveness 98 -> 100-98 = 2
     * - Face Match 95 -> 100-95 = 5
     * - Documento Vigente -> 0
     * - Horario Normal -> 0
     * Total = 7 puntos (Autorizado, ya que 7 < 80).
     */
    public String evaluateRisk(VerificationResult verificationResult) {
        ZonedDateTime zdt = ZonedDateTime.now(ZoneId.of("America/Argentina/Buenos_Aires"));
        int riskScore = calculateRiskScore(verificationResult, zdt.toLocalTime());

        if (riskScore >= riskThreshold) {
            return "BLOQUEAR";
        } else {
            return "AUTORIZAR";
        }
    }

    public int calculateRiskScore(VerificationResult verificationResult, LocalTime currentTime) {
        int riskScore = 0;

        // 1. Penalización Face Match (CU-0015)
        riskScore += Math.max(0, 100 - verificationResult.getFaceMatchScore());

        // 2. Penalización Liveness (CU-0014)
        riskScore += Math.max(0, 100 - verificationResult.getLivenessScore());

        // 3. Documento Vigente (Tri-estado)
        Boolean isLatest = verificationResult.getIsLatestDocument();
        if (Boolean.FALSE.equals(isLatest)) {
            riskScore += 50; 
        } // Si es true o null (UNKNOWN), suma 0.

        // 4. Horarios (CU-0022) - Evaluado en hora local enviada como parámetro
        if (currentTime.isAfter(LocalTime.of(3, 0)) && currentTime.isBefore(LocalTime.of(6, 0))) {
            riskScore += 20; // Madrugada
        } else if (currentTime.isAfter(LocalTime.of(8, 0)) && currentTime.isBefore(LocalTime.of(14, 0))) {
            riskScore += 10; // Horario Escolar
        }

        return Math.min(riskScore, 100); 
    }
}
