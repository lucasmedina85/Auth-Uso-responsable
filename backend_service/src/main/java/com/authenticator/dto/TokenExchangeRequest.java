package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class TokenExchangeRequest {
    @NotBlank(message = "client_id is required")
    private String clientId;

    @NotBlank(message = "redirect_uri is required")
    private String redirectUri;

    @NotBlank(message = "state is required")
    private String state;

    private String nonce;

    @NotBlank(message = "code_challenge is required")
    private String codeChallenge;

    @NotBlank(message = "code_challenge_method is required")
    private String codeChallengeMethod;

    @NotBlank(message = "scope is required")
    private String scope;

    @NotNull(message = "consent_given is required")
    private Boolean consentGiven;
}
