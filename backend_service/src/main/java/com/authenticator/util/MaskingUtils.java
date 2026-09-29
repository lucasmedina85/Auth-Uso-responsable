package com.authenticator.util;

public class MaskingUtils {
    public static String maskDni(String dni) {
        if (dni == null || dni.length() < 4) return "****";
        return "****" + dni.substring(dni.length() - 4);
    }
}
