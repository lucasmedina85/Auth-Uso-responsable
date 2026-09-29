package com.authenticator.service;

import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.VerificationSessionResponse;

public interface IdentityVerificationProvider {
    /**
     * Inicia una sesión hospedada de validación de identidad.
     * @param userId El ID interno del usuario
     * @return Respuesta con el ID de sesión del proveedor y la URL para redireccionar al usuario.
     */
    VerificationSessionResponse startVerification(String userId);

    /**
     * Consulta el resultado de una sesión.
     * @param sessionId El ID de sesión retornado en startVerification.
     * @return El resultado de la verificación.
     */
    VerificationResult getResult(String sessionId);

    /**
     * Verifica la disponibilidad del proveedor.
     * @return true si el servicio está operativo.
     */
    boolean checkHealth();
}
