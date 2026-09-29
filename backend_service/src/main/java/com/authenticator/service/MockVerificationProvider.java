package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.exception.BusinessDeclinedException;
import com.authenticator.exception.ProviderTimeoutException;
import com.authenticator.exception.ProviderUnavailableException;
import org.springframework.stereotype.Service;

import java.util.UUID;

@Service("mockProvider")
public class MockVerificationProvider implements IdentityVerificationProvider {

    private final MockDatabase mockDatabase;

    public MockVerificationProvider(MockDatabase mockDatabase) {
        this.mockDatabase = mockDatabase;
    }

    private void simulateLatencyAndErrors(String dni) {
        try {
            Thread.sleep(500);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        MockDatabase.MockProfile profile = mockDatabase.getProfile(dni);
        if ("5XX".equals(profile.status)) {
            throw new ProviderUnavailableException("Mock 5xx Error");
        }
        if ("TIMEOUT".equals(profile.status)) {
            throw new ProviderTimeoutException("Mock Timeout");
        }
    }

    @Override
    public DocumentResult verifyDocument(byte[] frontImage, byte[] backImage, String vendorData) {
        // En el mock, vendorData será el DNI simulado
        String dni = vendorData != null && !vendorData.isEmpty() ? vendorData : "11111111";
        simulateLatencyAndErrors(dni);
        
        MockDatabase.MockProfile profile = mockDatabase.getProfile(dni);

        if (profile.isExcluded || "REJECTED".equals(profile.status)) {
            throw new BusinessDeclinedException("Mock Document Rejected");
        }

        DocumentResult result = new DocumentResult();
        result.setStatus("Approved");
        result.setDocumentNumber(dni);
        result.setFirstName("Juan");
        result.setLastName("Perez");
        
        if (profile.isUnderage) {
            result.setDateOfBirth("2015-01-01"); // Menor de edad
        } else {
            result.setDateOfBirth("1990-01-01"); // Mayor de edad
        }
        result.setExpirationDate("2030-01-01"); // Vigente
        return result;
    }

    @Override
    public LivenessResult checkLiveness(byte[] userImage, String vendorData) {
        String dni = vendorData != null && !vendorData.isEmpty() ? vendorData : "11111111";
        simulateLatencyAndErrors(dni);

        MockDatabase.MockProfile profile = mockDatabase.getProfile(dni);
        
        if ("REJECTED_LIVENESS".equals(profile.status) || profile.livenessScore < 50) {
            throw new BusinessDeclinedException("Mock Liveness Rejected");
        }

        return new LivenessResult("Approved", profile.livenessScore);
    }

    @Override
    public FaceMatchResult matchFaces(byte[] userImage, byte[] refImage, String vendorData) {
        String dni = vendorData != null && !vendorData.isEmpty() ? vendorData : "11111111";
        simulateLatencyAndErrors(dni);

        MockDatabase.MockProfile profile = mockDatabase.getProfile(dni);
        
        if (profile.faceMatchScore < 50) {
            throw new BusinessDeclinedException("Mock Face Match Rejected");
        }

        return new FaceMatchResult("Approved", profile.faceMatchScore);
    }

    @Override
    public RegistryResult validateRegistry(String issuingState, String validationType, String firstName, String lastName, String dob, String personalNumber, String vendorData) {
        String dni = personalNumber != null && !personalNumber.isEmpty() ? personalNumber : "11111111";
        simulateLatencyAndErrors(dni);

        MockDatabase.MockProfile profile = mockDatabase.getProfile(dni);
        
        RegistryResult result = new RegistryResult();
        result.setStatus("Approved");
        result.setIsLatestDocument(profile.isLatestDocument);
        
        return result;
    }

    // --- Hosted/Legacy (Can return null or throw exception as they aren't used in Standalone pipeline) ---
    @Override
    public VerificationSessionResponse startVerification(String userId) { return null; }
    @Override
    public VerificationResult getResult(String sessionId) { return null; }
    @Override
    public VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName) { return null; }

    @Override
    public FingerprintResult verifyFingerprint(byte[] encryptedTemplate) {
        String simulatedDni = new String(encryptedTemplate).trim();
        MockDatabase.MockProfile profile = mockDatabase.getProfile(simulatedDni.isEmpty() ? "11111111" : simulatedDni);

        if (profile.fingerprintScore >= 90) {
            return new FingerprintResult("MATCH", profile.fingerprintScore);
        } else {
            return new FingerprintResult("NO_MATCH", profile.fingerprintScore);
        }
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
