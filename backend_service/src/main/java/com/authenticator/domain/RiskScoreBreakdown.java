package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class RiskScoreBreakdown {
    private int compositeScore; // 0 a 100
    private RiskDecision decision; // AUTORIZAR, REVISIÓN, BLOQUEAR
    private String hardRuleApplied; // null o ej. "EMULATOR_DETECTED"
    private Map<String, Integer> factorContributions;
    private Map<String, String> factorStatus;
    private List<RiskFactorBreakdown> details;
    private LocalDateTime evaluatedAt;

    public Map<String, Object> toAuditMap() {
        Map<String, Object> map = new HashMap<>();
        map.put("compositeScore", compositeScore);
        map.put("decision", decision != null ? decision.name() : null);
        map.put("hardRuleApplied", hardRuleApplied);
        map.put("factorContributions", factorContributions);
        map.put("factorStatus", factorStatus);
        map.put("evaluatedAt", evaluatedAt != null ? evaluatedAt.toString() : null);
        return map;
    }
}
