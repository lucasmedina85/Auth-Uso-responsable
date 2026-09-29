package com.authenticator.controller;

import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import com.authenticator.service.IdentityVerificationProvider;
import com.authenticator.service.VerificationSessionService;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/verification")
public class VerificationController {

    private final IdentityVerificationProvider provider;
    private final VerificationSessionService sessionService;

    public VerificationController(IdentityVerificationProvider provider, VerificationSessionService sessionService) {
        this.provider = provider;
        this.sessionService = sessionService;
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
            return ResponseEntity.noContent().build(); // 204 No Content if still pending
        }
        return ResponseEntity.ok(result);
    }

    @PostMapping("/webhook")
    public ResponseEntity<Void> handleWebhook(@RequestBody Map<String, Object> payload) {
        // TODO: Validar la firma HMAC usando DIDIT_WEBHOOK_SECRET
        
        String sessionId = (String) payload.get("session_id");
        String status = (String) payload.get("status");
        
        // Mapeo básico de ejemplo
        VerificationResult result = new VerificationResult();
        result.setMatchType(status); // "APPROVED", "REJECTED", etc.
        
        // Extraer score y validaciones si Didit los envía anidados
        // TODO: Revisar la estructura exacta del JSON de webhooks de Didit
        
        sessionService.updateSessionStatus(sessionId, result);
        return ResponseEntity.ok().build();
    }
}
