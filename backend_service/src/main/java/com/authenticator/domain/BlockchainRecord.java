package com.authenticator.domain;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Registro de auditoría on-chain (CU-0030 / CU-0047).
 *
 * REGLA DE PRIVACIDAD ESTRICTA:
 * Contiene únicamente hashes criptográficos, metadatos y veredictos cuantitativos.
 * NUNCA contiene IPs, nombres, datos personales (PII) ni desgloses detallados en texto claro.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BlockchainRecord {
    private String sessionHash;        // HMAC-SHA256(sessionId, secret)
    private String decision;           // AUTORIZAR, REVISIÓN, BLOQUEAR
    private int score;                 // 0 a 100
    private String riskConfigVersion;  // Versión de configuración de riesgo (ej. 1.0.0)
    private Instant timestamp;         // Marca temporal del registro
    private String breakdownHash;      // SHA-256 canónico del JSON del desglose
}
