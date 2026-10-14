package com.authenticator.service;

import com.authenticator.domain.NetworkRiskAnalysis;

public interface VpnDetectionProvider {
    NetworkRiskAnalysis checkIp(String ipAddress);
}
