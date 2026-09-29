package com.authenticator.controller;

import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import com.authenticator.service.IdentityVerificationProvider;
import com.authenticator.service.RiskEngineService;
import com.authenticator.service.VerificationSessionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/verification")
public class VerificationController {

    private final IdentityVerificationProvider provider;
    private final VerificationSessionService sessionService;
    private final RiskEngineService riskEngineService;

    public VerificationController(IdentityVerificationProvider provider, VerificationSessionService sessionService, RiskEngineService riskEngineService) {
        this.provider = provider;
        this.sessionService = sessionService;
        this.riskEngineService = riskEngineService;
    }

    @PostMapping("/start")
    public ResponseEntity<VerificationSessionResponse> startVerification(@RequestBody Map<String, String> body) {
        String userId = body.getOrDefault("userId", "default-user");
        VerificationSessionResponse response = provider.startVerification(userId);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/session/{sessionId}")
    public ResponseEntity<VerificationResult> getSessionStatus(@PathVariable String sessionId) {
        VerificationResult result = provider.getResult(sessionId);
        if (result == null) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.ok(result);
    }

    @PostMapping("/webhook")
    public ResponseEntity<Void> handleWebhook(@RequestBody Map<String, Object> payload) {
        String sessionId = (String) payload.get("session_id");
        String status = (String) payload.get("status");
        
        VerificationResult result = new VerificationResult();
        result.setMatchType(status); // APPROVED, REJECTED, etc.
        
        // Mapeo crudo para logs internos sin datos sensibles (solo estado general)
        result.setProviderRaw(Map.of("raw_status", status));

        if ("APPROVED".equals(status)) {
            // Doble validación: CU-0009. Disparamos la validación de DB directa contra RENAPER.
            // Nota: Aquí extraeríamos DNI, trámite, etc., del payload de Didit.
            try {
                // TODO: Extraer DNI y trámite del webhook payload de Didit
                String dniExtraido = "12345678"; // Dummy
                VerificationResult dbResult = provider.verifyIdentity(dniExtraido, null, "M", null, null);
                
                result.setLatestDocument(dbResult.isLatestDocument());
                result.setFaceMatchScore(95); // TODO: Leer de Didit payload
                result.setLivenessScore(98); // TODO: Leer de Didit payload
                
                // Evaluamos riesgo
                String riskDecision = riskEngineService.evaluateRisk(result);
                if ("BLOQUEAR".equals(riskDecision)) {
                    result.setMatchType("REJECTED_BY_RISK");
                }
            } catch (Exception e) {
                result.setMatchType("PENDING_DB_VALIDATION_FAILED");
            }
        }
        
        sessionService.updateSessionStatus(sessionId, result);
        return ResponseEntity.ok().build();
    }
}
