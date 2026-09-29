package com.authenticator.service;

import org.springframework.stereotype.Component;
import java.util.HashMap;
import java.util.Map;

@Component
public class MockDatabase {

    public static class MockProfile {
        public String dni;
        public String status; // APPROVED, REJECTED, 5XX, TIMEOUT
        public int faceMatchScore;
        public int livenessScore;
        public boolean isLatestDocument;
        public boolean isUnderage;
        public boolean isExcluded;
        public int fingerprintScore;

        public MockProfile(String dni, String status, int faceMatchScore, int livenessScore, boolean isLatestDocument, boolean isUnderage, boolean isExcluded, int fingerprintScore) {
            this.dni = dni;
            this.status = status;
            this.faceMatchScore = faceMatchScore;
            this.livenessScore = livenessScore;
            this.isLatestDocument = isLatestDocument;
            this.isUnderage = isUnderage;
            this.isExcluded = isExcluded;
            this.fingerprintScore = fingerprintScore;
        }
    }

    private final Map<String, MockProfile> db = new HashMap<>();

    public MockDatabase() {
        // 1. Válido y último ejemplar
        db.put("11111111", new MockProfile("11111111", "APPROVED", 95, 98, true, false, false, 95));
        
        // 2. Válido pero NO último ejemplar (Falla CU-0009)
        db.put("22222222", new MockProfile("22222222", "APPROVED", 95, 98, false, false, false, 95));
        
        // 3. Denunciado / Excluido (CU-0043)
        db.put("33333333", new MockProfile("33333333", "APPROVED", 95, 98, true, false, true, 95));
        
        // 4. Menor de edad
        db.put("44444444", new MockProfile("44444444", "APPROVED", 95, 98, true, true, false, 95));
        
        // 5. Coincidencia facial baja (Falla CU-0015)
        db.put("55555555", new MockProfile("55555555", "APPROVED", 40, 98, true, false, false, 95));
        
        // 6. Liveness fallido - pantalla detectada (Falla CU-0014)
        db.put("66666666", new MockProfile("66666666", "REJECTED_LIVENESS", 95, 10, true, false, false, 95));
        
        // 7. Huella con match insuficiente (Falla CU-0019)
        db.put("77777777", new MockProfile("77777777", "APPROVED", 95, 98, true, false, false, 30));
        
        // 8. Timeout simulado
        db.put("88888888", new MockProfile("88888888", "TIMEOUT", 0, 0, false, false, false, 0));
        
        // 9. Error 5xx simulado (Proveedor caído)
        db.put("99999999", new MockProfile("99999999", "5XX", 0, 0, false, false, false, 0));
    }

    public MockProfile getProfile(String dni) {
        // Default to successful profile if not found
        return db.getOrDefault(dni, db.get("11111111"));
    }
}
