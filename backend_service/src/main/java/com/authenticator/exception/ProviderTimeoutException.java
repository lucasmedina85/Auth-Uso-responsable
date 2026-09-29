package com.authenticator.exception;

public class ProviderTimeoutException extends RuntimeException {
    public ProviderTimeoutException(String message) {
        super(message);
    }
}
