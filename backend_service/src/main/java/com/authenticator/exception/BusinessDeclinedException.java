package com.authenticator.exception;

public class BusinessDeclinedException extends RuntimeException {
    public BusinessDeclinedException(String message) {
        super(message);
    }
}
