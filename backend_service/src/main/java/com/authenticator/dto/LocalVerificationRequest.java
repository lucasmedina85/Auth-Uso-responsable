package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

@Data
public class LocalVerificationRequest {
    @NotBlank
    private String dniHash;
}
