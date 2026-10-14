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
public class DeviceAlertResponse {

    private UUID id;
    private String deviceName;
    private String type; // PENDING_APPROVAL, DEVICE_REVOKED
    private String message;
    private LocalDateTime timestamp;
}
