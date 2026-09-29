package com.authenticator.service;

import com.authenticator.domain.FingerprintResult;
import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;

public interface IdentityVerificationProvider {

    // CU-0008 (Hosted Mode): Create session
    VerificationSessionResponse startVerification(String userId);

    // CU-0008, CU-0009, CU-0014, CU-0015 (Direct Mode or Background RENAPER Check)
    VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName);

    // Poll result of Hosted Mode
    VerificationResult getResult(String sessionId);

    // CU-0019: Cotejo Biométrico Dactilar
    FingerprintResult verifyFingerprint(byte[] encryptedTemplate);
    boolean supportsFingerprint();

    // CU-0044: Heartbeat
    boolean checkHealth();
}
