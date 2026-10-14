package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeviceRegistrationRequest {

    @NotBlank(message = "El identificador de dispositivo es requerido")
    private String deviceId;

    private String deviceName;
    private String manufacturer;
    private String osVersion;
    private String deviceType;
}
