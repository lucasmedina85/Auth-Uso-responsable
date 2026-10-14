package com.authenticator.exception;

public class OAuthInvalidGrantException extends OAuthException {
    public OAuthInvalidGrantException(String message) {
        super("invalid_grant", message);
    }
}
