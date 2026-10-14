package com.authenticator.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserActivityEventDTO {
    private String id;
    private LocalDateTime timestamp;
    private String type; // LOGIN, VALIDATION, DEVICE, OAUTH, SECURITY
    private String description;
    private String result; // SUCCESS, WARNING, FAILURE
    private String decision; // AUTORIZAR, REVISIÓN, BLOQUEAR (si aplica)
    private String maskedIp;
    private String txRef; // Referencia de blockchain si existe
    private Map<String, Object> metadata;
}
