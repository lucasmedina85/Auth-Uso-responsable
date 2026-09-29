package com.authenticator.domain;

public class VerificationSessionResponse {
    private String sessionId;
    private String url;

    public VerificationSessionResponse() {}

    public VerificationSessionResponse(String sessionId, String url) {
        this.sessionId = sessionId;
        this.url = url;
    }

    public String getSessionId() { return sessionId; }
    public void setSessionId(String sessionId) { this.sessionId = sessionId; }

    public String getUrl() { return url; }
    public void setUrl(String url) { this.url = url; }
}
