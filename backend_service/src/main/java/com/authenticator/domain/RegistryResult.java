package com.authenticator.domain;

public class RegistryResult {
    private String status;
    private Boolean isLatestDocument;

    public RegistryResult() {}
    public RegistryResult(String status, Boolean isLatestDocument) {
        this.status = status;
        this.isLatestDocument = isLatestDocument;
    }

    public String getStatus() { return status; }
    public void setStatus(String status) { this.status = status; }

    public Boolean getIsLatestDocument() { return isLatestDocument; }
    public void setIsLatestDocument(Boolean isLatestDocument) { this.isLatestDocument = isLatestDocument; }
}
