package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class NetworkRiskAnalysis {
    private NetworkRiskLevel riskLevel;
    private boolean isVpn;
    private boolean isProxy;
    private String asn;
    private String ipAddress;
    private String providerName;
    private String details;
}
