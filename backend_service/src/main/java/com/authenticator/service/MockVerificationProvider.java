package com.authenticator.service;

import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import org.springframework.stereotype.Service;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletableFuture;

@Service("mockProvider")
public class MockVerificationProvider implements IdentityVerificationProvider {

    private final VerificationSessionService sessionService;

    public MockVerificationProvider(VerificationSessionService sessionService) {
        this.sessionService = sessionService;
    }

    @Override
    public VerificationSessionResponse startVerification(String userId) {
        String sessionId = "mock-" + UUID.randomUUID().toString();
        String url = "http://localhost:8080/mock-web-flow?session=" + sessionId;

        // Initialize with PENDING (null)
        sessionService.updateSessionStatus(sessionId, null);

        // Simular que el usuario completa el flujo en 10 segundos
        CompletableFuture.runAsync(() -> {
            try {
                Thread.sleep(10000);
                VerificationResult mockResult = new VerificationResult(
                        "APPROVED",
                        95,
                        true,
                        Map.of("document_number", true, "gender", true)
                );
                sessionService.updateSessionStatus(sessionId, mockResult);
                System.out.println("Mock webhook auto-disparado para sesión: " + sessionId);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        return new VerificationSessionResponse(sessionId, url);
    }

    @Override
    public VerificationResult getResult(String sessionId) {
        return sessionService.getSessionStatus(sessionId);
    }

    @Override
    public boolean checkHealth() {
        return true;
    }
}
