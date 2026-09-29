package com.authenticator.service;

import com.authenticator.domain.VerificationResult;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

@Service
public class RiskEngineService {

    @Value("${app.thresholds.risk:80}")
    private int riskThreshold;

    public String evaluateRisk(VerificationResult verificationResult) {
        // Ponderaciones estáticas (Aritmética simple según CU-0023)
        // Valores de ejemplo para cumplir con CU-0023
        int faceMatchWeight = 40;
        int livenessWeight = 30;
        int documentValidityWeight = 30;

        int finalScore = 0;
        
        // Ponderar Face Match
        finalScore += (verificationResult.getFaceMatchScore() * faceMatchWeight) / 100;
        
        // Ponderar Liveness
        finalScore += (verificationResult.getLivenessScore() * livenessWeight) / 100;
        
        // Ponderar Documento (último ejemplar)
        if (verificationResult.isLatestDocument()) {
            finalScore += documentValidityWeight;
        }
        
        // TODO: Agregar penalizaciones por horario (CU-0022), VPN (CU-0032), etc.

        if (finalScore >= riskThreshold) {
            return "AUTORIZAR";
        } else {
            return "BLOQUEAR";
        }
    }
}
