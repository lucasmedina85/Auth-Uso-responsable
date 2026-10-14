package com.authenticator.domain;

import java.util.Map;

public class VerificationResult {
    private String matchType; // APPROVED, REJECTED, 5XX, TIMEOUT, PENDING, PROCESSING, FAILED
    private Integer faceMatchScore; 
    private Integer livenessScore; 
    private Boolean isLatestDocument; // Tri-estado: true, false, null (UNKNOWN)
    private Map<String, Boolean> fieldValidations;
    private Map<String, Object> providerRaw; 

    public VerificationResult() {}

    public String getMatchType() { return matchType; }
    public void setMatchType(String matchType) { this.matchType = matchType; }

    public Integer getFaceMatchScore() { return faceMatchScore; }
    public void setFaceMatchScore(Integer faceMatchScore) { this.faceMatchScore = faceMatchScore; }

    public Integer getLivenessScore() { return livenessScore; }
    public void setLivenessScore(Integer livenessScore) { this.livenessScore = livenessScore; }

    public Boolean getIsLatestDocument() { return isLatestDocument; }
    public void setIsLatestDocument(Boolean latestDocument) { isLatestDocument = latestDocument; }

    public Map<String, Boolean> getFieldValidations() { return fieldValidations; }
    public void setFieldValidations(Map<String, Boolean> fieldValidations) { this.fieldValidations = fieldValidations; }

    public Map<String, Object> getProviderRaw() { return providerRaw; }
    public void setProviderRaw(Map<String, Object> providerRaw) { this.providerRaw = providerRaw; }

    private Boolean emulatorDetected;
    public Boolean getEmulatorDetected() { return emulatorDetected; }
    public void setEmulatorDetected(Boolean emulatorDetected) { this.emulatorDetected = emulatorDetected; }

    private NetworkRiskLevel networkRiskLevel;
    public NetworkRiskLevel getNetworkRiskLevel() { return networkRiskLevel; }
    public void setNetworkRiskLevel(NetworkRiskLevel networkRiskLevel) { this.networkRiskLevel = networkRiskLevel; }

    private Boolean clientVpnDetected;
    public Boolean getClientVpnDetected() { return clientVpnDetected; }
    public void setClientVpnDetected(Boolean clientVpnDetected) { this.clientVpnDetected = clientVpnDetected; }

    private Boolean clientProxyDetected;
    public Boolean getClientProxyDetected() { return clientProxyDetected; }
    public void setClientProxyDetected(Boolean clientProxyDetected) { this.clientProxyDetected = clientProxyDetected; }

    private Double behavioralAdultScore;
    public Double getBehavioralAdultScore() { return behavioralAdultScore; }
    public void setBehavioralAdultScore(Double behavioralAdultScore) { this.behavioralAdultScore = behavioralAdultScore; }

    private Integer compositeRiskScore;
    public Integer getCompositeRiskScore() { return compositeRiskScore; }
    public void setCompositeRiskScore(Integer compositeRiskScore) { this.compositeRiskScore = compositeRiskScore; }

    private RiskDecision riskDecision;
    public RiskDecision getRiskDecision() { return riskDecision; }
    public void setRiskDecision(RiskDecision riskDecision) { this.riskDecision = riskDecision; }

    private RiskScoreBreakdown riskBreakdown;
    public RiskScoreBreakdown getRiskBreakdown() { return riskBreakdown; }
    public void setRiskBreakdown(RiskScoreBreakdown riskBreakdown) { this.riskBreakdown = riskBreakdown; }

    private Boolean deviceCompromised;
    public Boolean getDeviceCompromised() { return deviceCompromised; }
    public void setDeviceCompromised(Boolean deviceCompromised) { this.deviceCompromised = deviceCompromised; }

    private Integer failedFaceAttempts;
    public Integer getFailedFaceAttempts() { return failedFaceAttempts; }
    public void setFailedFaceAttempts(Integer failedFaceAttempts) { this.failedFaceAttempts = failedFaceAttempts; }

    private Boolean dniBlacklisted;
    public Boolean getDniBlacklisted() { return dniBlacklisted; }
    public void setDniBlacklisted(Boolean dniBlacklisted) { this.dniBlacklisted = dniBlacklisted; }

    private Boolean userLockedOut;
    public Boolean getUserLockedOut() { return userLockedOut; }
    public void setUserLockedOut(Boolean userLockedOut) { this.userLockedOut = userLockedOut; }
}
