package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.exception.BusinessDeclinedException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.Period;
import java.time.format.DateTimeFormatter;

@Service
public class IdentityVerificationService {

    private static final Logger logger = LoggerFactory.getLogger(IdentityVerificationService.class);
    private final IdentityVerificationProvider provider;
    private final RiskEngineService riskEngineService;

    public IdentityVerificationService(IdentityVerificationProvider provider, RiskEngineService riskEngineService) {
        this.provider = provider;
        this.riskEngineService = riskEngineService;
    }

    public VerificationResult executeStandalonePipeline(byte[] frontImage, byte[] backImage, byte[] selfie, String vendorData) {
        VerificationResult finalResult = new VerificationResult();
        try {
            // A. Document Verification (CU-0003, CU-0005)
            DocumentResult docResult = provider.verifyDocument(frontImage, backImage, vendorData);
            if ("Declined".equalsIgnoreCase(docResult.getStatus())) {
                finalResult.setMatchType("REJECTED_DOCUMENT_INVALID");
                return finalResult;
            }

            // Validar expiración (CU-0005)
            if (isExpired(docResult.getExpirationDate())) {
                finalResult.setMatchType("REJECTED_DOCUMENT_EXPIRED");
                return finalResult;
            }

            // Validar mayoría de edad (CU-0007)
            if (isUnderage(docResult.getDateOfBirth())) {
                finalResult.setMatchType("REJECTED_UNDERAGE");
                return finalResult;
            }

            // B. Passive Liveness (CU-0014)
            LivenessResult livenessResult = provider.checkLiveness(selfie, vendorData);
            if ("Declined".equalsIgnoreCase(livenessResult.getStatus())) {
                finalResult.setMatchType("REJECTED_LIVENESS_FAILED");
                return finalResult;
            }
            finalResult.setLivenessScore(livenessResult.getScore());

            // C. Face Match (CU-0015)
            // Se usa el selfie como user_image y el frontImage (o recorte) como ref_image.
            FaceMatchResult faceMatchResult = provider.matchFaces(selfie, frontImage, vendorData);
            if ("Declined".equalsIgnoreCase(faceMatchResult.getStatus())) {
                finalResult.setMatchType("REJECTED_FACE_MISMATCH");
                return finalResult;
            }
            finalResult.setFaceMatchScore(faceMatchResult.getScore());

            // D. Database Validation (CU-0009)
            RegistryResult registryResult = provider.validateRegistry("ARG", "renaper", 
                docResult.getFirstName(), docResult.getLastName(), docResult.getDateOfBirth(), docResult.getDocumentNumber(), vendorData);
            
            if ("Declined".equalsIgnoreCase(registryResult.getStatus())) {
                finalResult.setMatchType("REJECTED_REGISTRY_NOT_FOUND");
                return finalResult;
            }
            finalResult.setIsLatestDocument(registryResult.getIsLatestDocument());

            // CU-0023 Risk Evaluation
            String decision = riskEngineService.evaluateRisk(finalResult);
            if ("BLOQUEAR".equals(decision)) {
                finalResult.setMatchType("REJECTED_BY_RISK");
            } else {
                finalResult.setMatchType("APPROVED");
            }

        } catch (BusinessDeclinedException e) {
            logger.warn("Pipeline declined by provider: {}", e.getMessage());
            finalResult.setMatchType("REJECTED_BY_PROVIDER");
        } catch (Exception e) {
            logger.error("Error in standalone pipeline: {}", e.getMessage());
            finalResult.setMatchType("FAILED"); // Opcional, podría re-lanzarse para 5xx
            throw e; // Relanzamos para que actúe el circuit breaker si es necesario
        }

        return finalResult;
    }

    private boolean isExpired(String expirationDate) {
        if (expirationDate == null || expirationDate.isEmpty()) return false; // Delegate or assume valid if unparsed
        try {
            LocalDate exp = LocalDate.parse(expirationDate, DateTimeFormatter.ISO_LOCAL_DATE);
            return LocalDate.now().isAfter(exp);
        } catch (Exception e) {
            return false;
        }
    }

    private boolean isUnderage(String dob) {
        if (dob == null || dob.isEmpty()) return false;
        try {
            LocalDate birthDate = LocalDate.parse(dob, DateTimeFormatter.ISO_LOCAL_DATE);
            return Period.between(birthDate, LocalDate.now()).getYears() < 18;
        } catch (Exception e) {
            return false;
        }
    }
}
