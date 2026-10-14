package com.authenticator.exception;

public class OAuthAuthenticationException extends OAuthException {
    public OAuthAuthenticationException(String message) {
        super("invalid_client", message);
    }
}
