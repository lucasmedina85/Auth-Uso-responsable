package com.authenticator.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LinkedAppResponse {
    private UUID id;
    private String clientId;
    private String appName;
    private LocalDateTime linkedAt;
    private LocalDateTime lastUsedAt;
    private String status;
    private String tokenStatus;
    private String scopes;
}
