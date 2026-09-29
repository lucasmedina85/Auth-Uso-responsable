package com.authenticator.exception;

public class LivenessFailedException extends RuntimeException {
    public LivenessFailedException(String message) {
        super(message);
    }
}
