package com.authenticator.domain;

public class FingerprintResult {
    private String status; // MATCH, NO_MATCH, UNSUPPORTED
    private int matchScore; // 0 to 100

    public FingerprintResult(String status, int matchScore) {
        this.status = status;
        this.matchScore = matchScore;
    }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public int getMatchScore() { return matchScore; }
    public void setMatchScore(int matchScore) { this.matchScore = matchScore; }
}
