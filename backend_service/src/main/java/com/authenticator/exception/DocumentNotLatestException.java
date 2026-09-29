package com.authenticator.exception;

public class DocumentNotLatestException extends RuntimeException {
    public DocumentNotLatestException(String message) {
        super(message);
    }
}
