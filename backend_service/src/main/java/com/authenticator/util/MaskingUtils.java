package com.authenticator.util;

public class MaskingUtils {
    public static String maskDni(String dni) {
        if (dni == null || dni.length() < 4) return "****";
        return "****" + dni.substring(dni.length() - 4);
    }

    public static String maskIp(String ip) {
        if (ip == null || ip.isBlank()) {
            return "0.0.***.***";
        }
        if (ip.contains(".")) {
            String[] parts = ip.split("\\.");
            if (parts.length >= 2) {
                return parts[0] + "." + parts[1] + ".***.***";
            }
        } else if (ip.contains(":")) {
            String[] parts = ip.split(":");
            if (parts.length >= 2) {
                return parts[0] + ":" + parts[1] + ":***:***";
            }
        }
        return "***.***";
    }
}
