package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LocalVerificationRequest {
    @NotBlank
    private String dniHash;

    private Boolean emulatorDetected;
    private Boolean clientVpnDetected;
    private Boolean clientProxyDetected;
    private Double behavioralAdultScore;
    private java.util.Map<String, Object> aggregatedBehaviorMetrics;
    private Integer livenessScore;
    private Integer faceMatchScore;
    private Boolean isLatestDocument;
    private String attemptId;
    private Boolean deviceCompromised;
    private Integer failedFaceAttempts;
}
