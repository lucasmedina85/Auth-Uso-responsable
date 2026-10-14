package com.authenticator.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

@Component
public class IpResolver {

    private final List<String> trustedProxies;

    public IpResolver(@Value("${app.security.trusted-proxies:}") String trustedProxiesStr) {
        if (trustedProxiesStr == null || trustedProxiesStr.trim().isEmpty()) {
            this.trustedProxies = Collections.emptyList();
        } else {
            this.trustedProxies = Arrays.stream(trustedProxiesStr.split(","))
                    .map(String::trim)
                    .filter(s -> !s.isEmpty())
                    .toList();
        }
    }

    /**
     * Resuelve de forma segura la dirección IP del cliente (CU-0032).
     * No confía ciegamente en X-Forwarded-For a menos que la petición provenga
     * explícitamente de un proxy de confianza preconfigurado.
     */
    public String resolveClientIp(HttpServletRequest request) {
        if (request == null) {
            return "127.0.0.1";
        }

        String remoteAddr = request.getRemoteAddr();

        if (isTrustedProxy(remoteAddr)) {
            String xForwardedFor = request.getHeader("X-Forwarded-For");
            if (xForwardedFor != null && !xForwardedFor.trim().isEmpty()) {
                String[] parts = xForwardedFor.split(",");
                for (String part : parts) {
                    String candidate = part.trim();
                    if (!candidate.isEmpty() && !isTrustedProxy(candidate)) {
                        return cleanIp(candidate);
                    }
                }
            }
        }

        return cleanIp(remoteAddr);
    }

    public boolean isTrustedProxy(String ip) {
        if (ip == null) return false;
        String cleaned = cleanIp(ip);
        return trustedProxies.contains(cleaned);
    }

    public static String cleanIp(String ip) {
        if (ip == null || ip.trim().isEmpty()) return "127.0.0.1";
        String trimmed = ip.trim();
        if ("0:0:0:0:0:0:0:1".equals(trimmed) || "::1".equals(trimmed)) {
            return "127.0.0.1";
        }
        return trimmed;
    }

    /**
     * Enmascara la IP para evitar registrar datos sensibles en los logs.
     * Ejemplo: 198.51.100.23 -> 198.51.***.***
     */
    public static String maskIp(String ip) {
        if (ip == null || ip.isEmpty()) return "unknown";
        String cleaned = cleanIp(ip);
        if (cleaned.contains(".")) {
            String[] parts = cleaned.split("\\.");
            if (parts.length == 4) {
                return parts[0] + "." + parts[1] + ".***.***";
            }
        }
        return cleaned.length() > 4 ? cleaned.substring(0, 4) + "****" : "****";
    }
}
