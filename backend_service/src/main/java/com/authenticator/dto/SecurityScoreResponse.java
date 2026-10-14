package com.authenticator.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SecurityScoreResponse {

    private int score;
    private String level; // ALTO, MEDIO, BAJO
    private String levelDescription;
    private List<SecurityFactorDTO> factors;
}
