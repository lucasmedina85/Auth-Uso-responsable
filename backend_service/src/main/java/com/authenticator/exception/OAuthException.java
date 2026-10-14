package com.authenticator.exception;

public class OAuthException extends RuntimeException {
    private final String error;

    public OAuthException(String error, String message) {
        super(message);
        this.error = error;
    }

    public String getError() {
        return error;
    }
}
