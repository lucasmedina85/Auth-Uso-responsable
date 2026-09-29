package com.authenticator.domain;

import java.util.Map;

public class VerificationResult {
    private String matchType; // e.g. FULL_MATCH, PARTIAL, NO_MATCH, ABANDONED, EXPIRED
    private int faceMatchScore; // 0 to 100
    private boolean isLatestDocument;
    private Map<String, Boolean> fieldValidations;
    
    // Default constructor
    public VerificationResult() {}

    public VerificationResult(String matchType, int faceMatchScore, boolean isLatestDocument, Map<String, Boolean> fieldValidations) {
        this.matchType = matchType;
        this.faceMatchScore = faceMatchScore;
        this.isLatestDocument = isLatestDocument;
        this.fieldValidations = fieldValidations;
    }

    public String getMatchType() { return matchType; }
    public void setMatchType(String matchType) { this.matchType = matchType; }

    public int getFaceMatchScore() { return faceMatchScore; }
    public void setFaceMatchScore(int faceMatchScore) { this.faceMatchScore = faceMatchScore; }

    public boolean isLatestDocument() { return isLatestDocument; }
    public void setLatestDocument(boolean latestDocument) { isLatestDocument = latestDocument; }

    public Map<String, Boolean> getFieldValidations() { return fieldValidations; }
    public void setFieldValidations(Map<String, Boolean> fieldValidations) { this.fieldValidations = fieldValidations; }
}
