package com.authenticator.domain;

import java.util.Map;

public class VerificationResult {
    private String matchType; // e.g. FULL_MATCH, PARTIAL, NO_MATCH, ABANDONED, EXPIRED, PENDING
    private int faceMatchScore; // 0 to 100
    private int livenessScore; // 0 to 100
    private boolean isLatestDocument;
    private Map<String, Boolean> fieldValidations;
    private Map<String, Object> providerRaw; // For internal logging only

    public VerificationResult() {}

    public String getMatchType() { return matchType; }
    public void setMatchType(String matchType) { this.matchType = matchType; }

    public int getFaceMatchScore() { return faceMatchScore; }
    public void setFaceMatchScore(int faceMatchScore) { this.faceMatchScore = faceMatchScore; }

    public int getLivenessScore() { return livenessScore; }
    public void setLivenessScore(int livenessScore) { this.livenessScore = livenessScore; }

    public boolean isLatestDocument() { return isLatestDocument; }
    public void setLatestDocument(boolean latestDocument) { isLatestDocument = latestDocument; }

    public Map<String, Boolean> getFieldValidations() { return fieldValidations; }
    public void setFieldValidations(Map<String, Boolean> fieldValidations) { this.fieldValidations = fieldValidations; }

    public Map<String, Object> getProviderRaw() { return providerRaw; }
    public void setProviderRaw(Map<String, Object> providerRaw) { this.providerRaw = providerRaw; }
}
