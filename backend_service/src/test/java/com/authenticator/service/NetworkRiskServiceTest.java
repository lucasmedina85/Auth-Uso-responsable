package com.authenticator.service;

import com.authenticator.domain.NetworkRiskAnalysis;
import com.authenticator.domain.NetworkRiskLevel;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

public class NetworkRiskServiceTest {

    private NetworkRiskService networkRiskService;

    @BeforeEach
    public void setup() {
        MockVpnDetectionProvider mockProvider = new MockVpnDetectionProvider(
                new String[]{"10.8.0.0/24", "198.51.100.0/24", "172.16.0.0/12"},
                new String[]{"AS16509", "AS14061", "AS9009"}
        );
        networkRiskService = new NetworkRiskService(mockProvider);
    }

    @Test
    public void evaluateNetworkRisk_CleanResidentialIp_ReturnsBajo() {
        NetworkRiskAnalysis analysis = networkRiskService.evaluateNetworkRisk("190.246.50.12", false, false);
        assertEquals(NetworkRiskLevel.BAJO, analysis.getRiskLevel());
    }

    @Test
    public void evaluateNetworkRisk_VpnCidrRange_ReturnsAlto() {
        NetworkRiskAnalysis analysis = networkRiskService.evaluateNetworkRisk("198.51.100.42", false, false);
        assertEquals(NetworkRiskLevel.ALTO, analysis.getRiskLevel());
        assertTrue(analysis.isVpn());
    }

    @Test
    public void evaluateNetworkRisk_VpnAsn_ReturnsAlto() {
        NetworkRiskAnalysis analysis = networkRiskService.evaluateNetworkRisk("54.12.34.56", false, false);
        assertEquals(NetworkRiskLevel.ALTO, analysis.getRiskLevel());
        assertEquals("AS16509", analysis.getAsn());
    }

    @Test
    public void evaluateNetworkRisk_CleanIpWithUntrustedClientSignal_ElevatesOnlyToMedio() {
        // CU-0032: La señal del cliente es no confiable; eleva a MEDIO por sospecha pero nunca a ALTO por sí sola
        NetworkRiskAnalysis analysis = networkRiskService.evaluateNetworkRisk("190.246.50.12", true, false);
        assertEquals(NetworkRiskLevel.MEDIO, analysis.getRiskLevel());
        assertTrue(analysis.isVpn());
    }
}
