package com.authenticator.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.util.Set;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ClientInfoResponse {
    private String clientId;
    private String clientName;
    private String redirectUri;
    private Set<String> allowedScopes;
}
