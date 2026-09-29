package com.authenticator.service;

import com.authenticator.domain.*;

public interface IdentityVerificationProvider {

    // Modo Standalone Granular
    DocumentResult verifyDocument(byte[] frontImage, byte[] backImage, String vendorData);
    LivenessResult checkLiveness(byte[] userImage, String vendorData);
    FaceMatchResult matchFaces(byte[] userImage, byte[] refImage, String vendorData);
    RegistryResult validateRegistry(String issuingState, String validationType, String firstName, String lastName, String dob, String personalNumber, String vendorData);

    // Modo Hosted Legacy
    VerificationSessionResponse startVerification(String userId);
    VerificationResult getResult(String sessionId);

    // Compatibilidad/Old (ya no se usa en el pipeline principal, reemplazado por standalone)
    VerificationResult verifyIdentity(String dni, String tramite, String gender, byte[] selfie, String firstName);

    // Huella
    FingerprintResult verifyFingerprint(byte[] encryptedTemplate);
    boolean supportsFingerprint();

    // Circuit Breaker Health
    boolean checkHealth();
}
