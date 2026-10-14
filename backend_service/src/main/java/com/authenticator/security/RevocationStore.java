package com.authenticator.security;

import java.time.Duration;

/**
 * Almacén de revocación activa de tokens (CU-0037).
 * Permite verificar revocación en memoria o Redis en tiempo O(1) con TTL automático.
 */
public interface RevocationStore {

    /**
     * Registra un token (jti) como revocado con un tiempo de vida (TTL).
     */
    void revoke(String jti, Duration ttl);

    /**
     * Consulta si un token (jti) se encuentra revocado.
     */
    boolean isRevoked(String jti);
}
