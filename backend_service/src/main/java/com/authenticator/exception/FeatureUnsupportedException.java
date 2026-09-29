package com.authenticator.exception;

public class FeatureUnsupportedException extends RuntimeException {
    public FeatureUnsupportedException(String message) {
        super(message);
    }
}
