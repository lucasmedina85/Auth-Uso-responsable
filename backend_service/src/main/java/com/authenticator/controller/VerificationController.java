package com.authenticator.controller;

import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;
import com.authenticator.exception.FeatureUnsupportedException;
import com.authenticator.service.IdentityVerificationProvider;
import com.authenticator.service.IdentityVerificationService;
import com.authenticator.service.RiskEngineService;
import com.authenticator.service.VerificationSessionService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.core.env.Profiles;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

@RestController
@RequestMapping("/api/v1/verification")
public class VerificationController {

    private static final Logger logger = LoggerFactory.getLogger(VerificationController.class);

    private final IdentityVerificationProvider provider;
    private final IdentityVerificationService identityVerificationService;
    private final VerificationSessionService sessionService;
    private final RiskEngineService riskEngineService;
    private final Environment env;
    private final ExecutorService executorService;

    @Value("${app.didit.webhook-secret:}")
    private String webhookSecret;

    @Value("${app.identity-provider:mock}")
    private String identityProvider;

    public VerificationController(IdentityVerificationProvider provider, IdentityVerificationService identityVerificationService, VerificationSessionService sessionService, RiskEngineService riskEngineService, Environment env) {
        this.provider = provider;
        this.identityVerificationService = identityVerificationService;
        this.sessionService = sessionService;
        this.riskEngineService = riskEngineService;
        this.env = env;
        this.executorService = Executors.newFixedThreadPool(10);
    }

    // --- MODO STANDALONE (NUEVO POR DEFECTO) ---

    @PostMapping(value = "/standalone", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<VerificationResult> executeStandalonePipeline(
            @RequestParam("front_image") MultipartFile frontImage,
            @RequestParam(value = "back_image", required = false) MultipartFile backImage,
            @RequestParam("user_image") MultipartFile userImage,
            @RequestParam(value = "vendor_data", defaultValue = "default-user") String vendorData) {
        try {
            byte[] frontBytes = frontImage.getBytes();
            byte[] backBytes = backImage != null ? backImage.getBytes() : null;
            byte[] userBytes = userImage.getBytes();

            VerificationResult result = identityVerificationService.executeStandalonePipeline(frontBytes, backBytes, userBytes, vendorData);
            return ResponseEntity.ok(result);
        } catch (IOException e) {
            return ResponseEntity.badRequest().build();
        }
    }

    // --- MODO HOSTED LEGACY ---

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
    public ResponseEntity<Void> handleWebhook(
            @RequestHeader(value = "X-Signature-V2", required = false) String signature,
            @RequestBody String rawPayload,
            @RequestBody Map<String, Object> payload) {
        
        String sessionId = (String) payload.get("session_id");

        VerificationResult existing = sessionService.getSessionStatus(sessionId);
        if (existing != null) {
            String type = existing.getMatchType();
            if ("DONE".equals(type) || "FAILED".equals(type) || "PROCESSING".equals(type)) {
                return ResponseEntity.ok().build();
            }
        }

        if (!env.acceptsProfiles(Profiles.of("test"))) {
            if (webhookSecret == null || webhookSecret.isEmpty() || !isValidSignature(signature, rawPayload)) {
                logger.warn("Webhook HMAC signature validation failed for session: {}", sessionId);
                return ResponseEntity.status(401).build();
            }
        }

        VerificationResult processingState = new VerificationResult();
        processingState.setMatchType("PROCESSING");
        sessionService.updateSessionStatus(sessionId, processingState);

        executorService.submit(() -> processWebhookPayload(sessionId, payload));

        return ResponseEntity.ok().build();
    }

    private void processWebhookPayload(String sessionId, Map<String, Object> payload) {
        String status = (String) payload.get("status");
        
        VerificationResult result = new VerificationResult();
        result.setProviderRaw(Map.of("raw_status", status));

        if ("APPROVED".equals(status)) {
            try {
                String vendorDataDni = (String) payload.get("vendor_data");
                if (vendorDataDni == null) vendorDataDni = "11111111"; 

                if ("didit".equals(identityProvider)) {
                    result.setFaceMatchScore(95); 
                    result.setLivenessScore(98);
                    result.setIsLatestDocument(null);
                } else {
                    VerificationResult dbResult = provider.verifyIdentity(vendorDataDni, null, "M", null, null);
                    result.setIsLatestDocument(dbResult.getIsLatestDocument());
                    result.setFaceMatchScore(dbResult.getFaceMatchScore());
                    result.setLivenessScore(dbResult.getLivenessScore());
                    
                    if (Boolean.FALSE.equals(dbResult.getIsLatestDocument())) {
                        result.setMatchType("REJECTED_DOCUMENT_NOT_LATEST");
                        sessionService.updateSessionStatus(sessionId, result);
                        return;
                    } else if (dbResult.getMatchType() != null && dbResult.getMatchType().contains("REJECTED")) {
                        result.setMatchType(dbResult.getMatchType());
                        sessionService.updateSessionStatus(sessionId, result);
                        return;
                    }
                }
                
                String riskDecision = riskEngineService.evaluateRisk(result);
                if ("BLOQUEAR".equals(riskDecision)) {
                    result.setMatchType("REJECTED_BY_RISK");
                } else {
                    result.setMatchType("DONE");
                }
            } catch (FeatureUnsupportedException e) {
                result.setIsLatestDocument(null);
                result.setMatchType("DONE");
                logger.info("FeatureUnsupportedException caught, marking isLatestDocument as UNKNOWN");
            } catch (Exception e) {
                logger.error("Error processing webhook async payload: {}", e.getMessage());
                result.setMatchType("FAILED");
            }
        } else {
            result.setMatchType(status); 
        }
        
        sessionService.updateSessionStatus(sessionId, result);
    }

    private boolean isValidSignature(String signature, String rawPayload) {
        if (signature == null || signature.isEmpty()) return false;
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKeySpec = new SecretKeySpec(webhookSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(secretKeySpec);
            byte[] hmacBytes = mac.doFinal(rawPayload.getBytes(StandardCharsets.UTF_8));
            
            StringBuilder sb = new StringBuilder();
            for (byte b : hmacBytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString().equalsIgnoreCase(signature);
        } catch (Exception e) {
            logger.error("Error calculating HMAC", e);
            return false;
        }
    }
}
