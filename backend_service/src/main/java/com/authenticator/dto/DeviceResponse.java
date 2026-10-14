package com.authenticator.dto;

import com.authenticator.domain.TrustedDeviceStatus;
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
public class DeviceResponse {

    private UUID id;
    private String deviceHash;
    private String deviceName;
    private String manufacturer;
    private String osVersion;
    private String deviceType;
    private TrustedDeviceStatus status;
    private boolean isCurrent;
    private LocalDateTime firstSeenAt;
    private LocalDateTime lastSeenAt;
    private LocalDateTime trustEvaluatedAt;
    private LocalDateTime revokedAt;
}
