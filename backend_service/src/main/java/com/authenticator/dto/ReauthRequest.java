package com.authenticator.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class ReauthRequest {
    @NotBlank(message = "La contraseña actual es requerida")
    private String password;
}
