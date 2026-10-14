package com.authenticator.service;

import com.authenticator.domain.NetworkRiskAnalysis;
import com.authenticator.domain.NetworkRiskLevel;
import com.authenticator.util.IpResolver;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class NetworkRiskService {

    private static final Logger logger = LoggerFactory.getLogger(NetworkRiskService.class);

    private final VpnDetectionProvider vpnDetectionProvider;

    public NetworkRiskService(VpnDetectionProvider vpnDetectionProvider) {
        this.vpnDetectionProvider = vpnDetectionProvider;
    }

    /**
     * Evalúa el nivel de riesgo de red (CU-0032).
     *
     * IMPORTANTE - Regla de Confianza:
     * Las señales reportadas por el cliente ('clientVpnDetected', 'clientProxyDetected')
     * son tratadas como NO CONFIABLES debido a que el dispositivo o la aplicación
     * pueden ser manipulados por un atacante. Por ende, la evidencia verificada por el backend
     * (la dirección IP real del cliente y su pertenencia a rangos/ASNs de VPN) tiene prioridad y
     * mayor peso probatorio.
     */
    public NetworkRiskAnalysis evaluateNetworkRisk(String clientIp, Boolean clientVpnDetected, Boolean clientProxyDetected) {
        String maskedIp = IpResolver.maskIp(clientIp);
        logger.info("Analizando riesgo de red para IP cliente: {}", maskedIp);

        // 1. Evaluación verificada por el backend
        NetworkRiskAnalysis ipAnalysis = vpnDetectionProvider.checkIp(clientIp);

        boolean clientReportedAnomaly = Boolean.TRUE.equals(clientVpnDetected) || Boolean.TRUE.equals(clientProxyDetected);

        NetworkRiskLevel finalRiskLevel = ipAnalysis.getRiskLevel();

        // 2. Fusión con señales de cliente (con menor peso)
        if (ipAnalysis.getRiskLevel() == NetworkRiskLevel.ALTO) {
            // Confirmado por backend
            finalRiskLevel = NetworkRiskLevel.ALTO;
        } else if (ipAnalysis.getRiskLevel() == NetworkRiskLevel.MEDIO) {
            if (clientReportedAnomaly) {
                finalRiskLevel = NetworkRiskLevel.ALTO;
            }
        } else {
            // Backend detectó IP residencial limpia (BAJO).
            // Si el cliente reporta VPN/proxy, se eleva a MEDIO por inconsistencia/sospecha,
            // pero nunca a ALTO por sí sola al ser señal no confiable.
            if (clientReportedAnomaly) {
                finalRiskLevel = NetworkRiskLevel.MEDIO;
                logger.warn("Señal de VPN/proxy reportada por el cliente sobre IP residencial: {}. Elevando a MEDIO.", maskedIp);
            }
        }

        return NetworkRiskAnalysis.builder()
                .riskLevel(finalRiskLevel)
                .isVpn(ipAnalysis.isVpn() || Boolean.TRUE.equals(clientVpnDetected))
                .isProxy(ipAnalysis.isProxy() || Boolean.TRUE.equals(clientProxyDetected))
                .asn(ipAnalysis.getAsn())
                .ipAddress(clientIp)
                .providerName(ipAnalysis.getProviderName())
                .details(ipAnalysis.getDetails() + (clientReportedAnomaly ? " [Cliente reportó VPN/Proxy]" : ""))
                .build();
    }
}
