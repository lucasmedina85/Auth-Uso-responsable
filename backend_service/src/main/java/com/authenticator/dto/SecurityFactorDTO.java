package com.authenticator.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SecurityFactorDTO {

    private String name;
    private String description;
    private int contribution;
    private String status; // POSITIVE, NEUTRAL, NEGATIVE
}
