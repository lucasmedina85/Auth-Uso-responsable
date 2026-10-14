package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class UnlinkAppRequest {
    @NotBlank(message = "clientId es obligatorio")
    private String clientId;
}
