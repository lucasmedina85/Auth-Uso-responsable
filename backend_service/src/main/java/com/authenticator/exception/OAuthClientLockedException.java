package com.authenticator.exception;

public class OAuthClientLockedException extends OAuthException {
    private final long retryAfterSeconds;

    public OAuthClientLockedException(String message, long retryAfterSeconds) {
        super("temporarily_unavailable", message);
        this.retryAfterSeconds = retryAfterSeconds;
    }

    public long getRetryAfterSeconds() {
        return retryAfterSeconds;
    }
}
