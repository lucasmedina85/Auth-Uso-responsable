package com.authenticator.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class OAuthRateLimitingTest {

    @Autowired
    private OAuthRateLimitingService rateLimitingService;

    @BeforeEach
    public void setUp() {
        rateLimitingService.resetForTests();
    }

    @Test
    public void clientSecretFailures_LockoutAfterThreshold() {
        String clientId = "test-client-lockout";
        assertFalse(rateLimitingService.isClientLocked(clientId));

        // Registrar 4 fallas (por debajo del umbral de 5)
        for (int i = 0; i < 4; i++) {
            rateLimitingService.recordClientSecretFailure(clientId);
            assertFalse(rateLimitingService.isClientLocked(clientId));
        }

        // 5ta falla -> activación del bloqueo temporal
        rateLimitingService.recordClientSecretFailure(clientId);
        assertTrue(rateLimitingService.isClientLocked(clientId));
        assertTrue(rateLimitingService.getRemainingLockoutSeconds(clientId) > 0);

        // Reset de éxito limpia el bloqueo
        rateLimitingService.recordClientSecretSuccess(clientId);
        assertFalse(rateLimitingService.isClientLocked(clientId));
    }

    @Test
    public void ipRateLimiting_RejectsBurstExceedingLimit() {
        String ipKey = "192.0.2.100";
        // Hasta 30 peticiones por minuto permitidas
        for (int i = 0; i < 30; i++) {
            assertTrue(rateLimitingService.checkRequestRateLimit(ipKey), "Request " + (i + 1) + " debe ser permitida");
        }

        // Petición 31 debe ser bloqueada por rate limit
        assertFalse(rateLimitingService.checkRequestRateLimit(ipKey), "Petición que excede el límite debe ser rechazada");
    }
}
