package com.authenticator.dto;

import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
public class OAuthTokenRequest {
    private String grantType;
    private String code;
    private String redirectUri;
    private String codeVerifier;
    private String clientId;
    private String clientSecret;
}
