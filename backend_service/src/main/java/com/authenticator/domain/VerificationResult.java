package com.authenticator.domain;

import java.util.Map;

public class VerificationResult {
    private String matchType; // APPROVED, REJECTED, 5XX, TIMEOUT, PENDING, PROCESSING, FAILED
    private int faceMatchScore; 
    private int livenessScore; 
    private Boolean isLatestDocument; // Tri-estado: true, false, null (UNKNOWN)
    private Map<String, Boolean> fieldValidations;
    private Map<String, Object> providerRaw; 

    public VerificationResult() {}

    public String getMatchType() { return matchType; }
    public void setMatchType(String matchType) { this.matchType = matchType; }

    public int getFaceMatchScore() { return faceMatchScore; }
    public void setFaceMatchScore(int faceMatchScore) { this.faceMatchScore = faceMatchScore; }

    public int getLivenessScore() { return livenessScore; }
    public void setLivenessScore(int livenessScore) { this.livenessScore = livenessScore; }

    public Boolean getIsLatestDocument() { return isLatestDocument; }
    public void setIsLatestDocument(Boolean latestDocument) { isLatestDocument = latestDocument; }

    public Map<String, Boolean> getFieldValidations() { return fieldValidations; }
    public void setFieldValidations(Map<String, Boolean> fieldValidations) { this.fieldValidations = fieldValidations; }

    public Map<String, Object> getProviderRaw() { return providerRaw; }
    public void setProviderRaw(Map<String, Object> providerRaw) { this.providerRaw = providerRaw; }
}
