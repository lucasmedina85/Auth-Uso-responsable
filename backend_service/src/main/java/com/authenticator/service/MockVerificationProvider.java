package com.authenticator.service;

import com.authenticator.domain.FingerprintResult;
import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import com.authenticator.exception.DocumentNotLatestException;
import com.authenticator.exception.LivenessFailedException;
import com.authenticator.exception.ProviderUnavailableException;
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

        sessionService.updateSessionStatus(sessionId, null);

        CompletableFuture.runAsync(() -> {
            try {
                Thread.sleep(5000); // Simulamos menor latencia para agilizar tests manuales
                
                // MOCK: Dependiendo del userId o de un estado interno, simulamos diferentes resultados
                VerificationResult mockResult = new VerificationResult();
                if ("user-liveness-fail".equals(userId)) {
                    mockResult.setMatchType("REJECTED");
                    mockResult.setLivenessScore(10);
                } else {
                    mockResult.setMatchType("APPROVED");
                    mockResult.setLivenessScore(95);
                    mockResult.setFaceMatchScore(92);
                    mockResult.setLatestDocument(true);
                }
                
                sessionService.updateSessionStatus(sessionId, mockResult);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });

        return new VerificationSessionResponse(sessionId, url);
    }

    @Override
    public VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName) {
        // Simulación estática para CU-0009 y tests
        if ("500".equals(dni)) throw new ProviderUnavailableException("Mock 5xx Error");
        if ("00000000".equals(dni)) throw new DocumentNotLatestException("Document is not the latest exemplar");
        if ("11111111".equals(dni)) throw new LivenessFailedException("Liveness verification failed");

        VerificationResult result = new VerificationResult();
        result.setMatchType("FULL_MATCH");
        result.setFaceMatchScore(95);
        result.setLivenessScore(98);
        result.setLatestDocument(true);
        result.setFieldValidations(Map.of("document_number", true, "gender", true));
        return result;
    }

    @Override
    public VerificationResult getResult(String sessionId) {
        return sessionService.getSessionStatus(sessionId);
    }

    @Override
    public FingerprintResult verifyFingerprint(byte[] encryptedTemplate) {
        // CU-0019 (Completo en Mock)
        return new FingerprintResult("MATCH", 95);
    }

    @Override
    public boolean supportsFingerprint() {
        return true;
    }

    @Override
    public boolean checkHealth() {
        return true;
    }
}
