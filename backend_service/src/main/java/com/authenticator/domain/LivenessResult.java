package com.authenticator.domain;

public class LivenessResult {
    private String status;
    private int score;

    public LivenessResult() {}
    public LivenessResult(String status, int score) { this.status = status; this.score = score; }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public int getScore() { return score; }
    public void setScore(int score) { this.score = score; }
}
