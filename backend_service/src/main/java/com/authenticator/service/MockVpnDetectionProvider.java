package com.authenticator.service;

import com.authenticator.domain.NetworkRiskAnalysis;
import com.authenticator.domain.NetworkRiskLevel;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.annotation.PostConstruct;

@Service
@ConditionalOnProperty(name = "app.security.vpn.provider", havingValue = "mock", matchIfMissing = true)
public class MockVpnDetectionProvider implements VpnDetectionProvider {

    private static final Logger logger = LoggerFactory.getLogger(MockVpnDetectionProvider.class);

    private final List<String> blockedRanges;
    private final List<String> blockedAsns;

    public MockVpnDetectionProvider(
            @Value("${app.security.vpn.blocked-ranges:10.8.0.0/24,198.51.100.0/24,172.16.0.0/12}") String[] blockedRanges,
            @Value("${app.security.vpn.blocked-asns:AS16509,AS14061,AS9009}") String[] blockedAsns) {
        this.blockedRanges = blockedRanges != null ? Arrays.asList(blockedRanges) : Collections.emptyList();
        this.blockedAsns = blockedAsns != null ? Arrays.asList(blockedAsns) : Collections.emptyList();
    }

    @PostConstruct
    public void logMockVpnWarning() {
        logger.warn("****************************************************************************************");
        logger.warn("⚠️  [ADVERTENCIA DE SEGURIDAD]: Proveedor IP Intelligence/VPN ACTIVO es 'MOCK'");
        logger.warn("⚠️  La clasificación de ASN y rangos bloqueados opera sin conexión a servicios de GeoIP.");
        logger.warn("⚠️  Este modo es EXCLUSIVO para desarrollo/pruebas locales.");
        logger.warn("****************************************************************************************");
    }

    @Override
    public NetworkRiskAnalysis checkIp(String ipAddress) {
        String cleanIp = ipAddress != null ? ipAddress.trim() : "127.0.0.1";

        // Check against blocked CIDR ranges
        for (String cidr : blockedRanges) {
            if (matchesCidr(cleanIp, cidr.trim())) {
                return NetworkRiskAnalysis.builder()
                        .riskLevel(NetworkRiskLevel.ALTO)
                        .isVpn(true)
                        .isProxy(false)
                        .asn("AS-MOCK-VPN")
                        .ipAddress(cleanIp)
                        .providerName("MockVpnDetectionProvider")
                        .details("IP en rango bloqueado de VPN/Hosting: " + cidr)
                        .build();
            }
        }

        // Mock ASN association for test IPs
        String mockAsn = resolveMockAsn(cleanIp);
        if (mockAsn != null && blockedAsns.contains(mockAsn)) {
            return NetworkRiskAnalysis.builder()
                    .riskLevel(NetworkRiskLevel.ALTO)
                    .isVpn(true)
                    .isProxy(false)
                    .asn(mockAsn)
                    .ipAddress(cleanIp)
                    .providerName("MockVpnDetectionProvider")
                    .details("ASN categorizado como proveedor de VPN/Datacenter: " + mockAsn)
                    .build();
        }

        // Suspect proxy / CGNAT ranges
        if (cleanIp.startsWith("100.64.") || cleanIp.startsWith("192.0.2.")) {
            return NetworkRiskAnalysis.builder()
                    .riskLevel(NetworkRiskLevel.MEDIO)
                    .isVpn(false)
                    .isProxy(true)
                    .asn("AS-CGNAT-PROXY")
                    .ipAddress(cleanIp)
                    .providerName("MockVpnDetectionProvider")
                    .details("IP sospechosa de proxy/carrier-grade NAT")
                    .build();
        }

        // Clean residential IP
        return NetworkRiskAnalysis.builder()
                .riskLevel(NetworkRiskLevel.BAJO)
                .isVpn(false)
                .isProxy(false)
                .asn("AS10481") // Telecom Argentina / Fibertel
                .ipAddress(cleanIp)
                .providerName("MockVpnDetectionProvider")
                .details("Conexión de red residencial legítima")
                .build();
    }

    private String resolveMockAsn(String ip) {
        if (ip.startsWith("54.") || ip.startsWith("52.")) return "AS16509"; // AWS
        if (ip.startsWith("167.99.") || ip.startsWith("159.65.")) return "AS14061"; // DigitalOcean
        if (ip.startsWith("185.220.")) return "AS9009"; // Tor / VPN
        return null;
    }

    public static boolean matchesCidr(String ip, String cidr) {
        try {
            if (!cidr.contains("/")) {
                return ip.equals(cidr);
            }
            String[] parts = cidr.split("/");
            String network = parts[0];
            int prefix = Integer.parseInt(parts[1]);

            long ipLong = ipToLong(ip);
            long networkLong = ipToLong(network);
            long mask = prefix == 0 ? 0 : (-1L << (32 - prefix)) & 0xFFFFFFFFL;

            return (ipLong & mask) == (networkLong & mask);
        } catch (Exception e) {
            return false;
        }
    }

    private static long ipToLong(String ip) {
        String[] octets = ip.split("\\.");
        if (octets.length != 4) return 0;
        long result = 0;
        for (int i = 0; i < 4; i++) {
            result = (result << 8) | (Integer.parseInt(octets[i]) & 0xFF);
        }
        return result & 0xFFFFFFFFL;
    }
}
