package com.authenticator.exception;

public class OAuthRiskNotAuthorizedException extends OAuthException {
    public OAuthRiskNotAuthorizedException(String message) {
        super("risk_decision_not_authorized", message);
    }
}
