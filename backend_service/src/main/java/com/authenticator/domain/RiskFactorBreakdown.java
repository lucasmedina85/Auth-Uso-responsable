package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RiskFactorBreakdown {
    private String factorName;
    private int contribution;
    private int maxWeight;
    private String status; // EVALUATED, MISSING_IGNORED, MISSING_PENALIZED, HARD_RULE_TRIGGERED
    private String details; // Safe details without PII or unmasked IP
}
