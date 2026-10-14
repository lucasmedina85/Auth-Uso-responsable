package com.authenticator.security;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.annotation.PostConstruct;

@Component
@ConditionalOnProperty(name = "app.revocation.store", havingValue = "memory", matchIfMissing = true)
public class InMemoryRevocationStore implements RevocationStore {

    private static final Logger logger = LoggerFactory.getLogger(InMemoryRevocationStore.class);

    private final ConcurrentMap<String, Instant> store = new ConcurrentHashMap<>();

    @PostConstruct
    public void logInMemoryRevocationWarning() {
        logger.warn("****************************************************************************************");
        logger.warn("⚠️  [ADVERTENCIA DE SEGURIDAD]: Almacén de Revocación de Tokens ACTIVO es 'IN-MEMORY'");
        logger.warn("⚠️  Las revocaciones activas no persisten entre reinicios ni se comparten entre réplicas.");
        logger.warn("⚠️  Para entornos de producción distribuidos, configure app.revocation.store=redis.");
        logger.warn("****************************************************************************************");
    }

    @Override
    public void revoke(String jti, Duration ttl) {
        if (jti == null || jti.isBlank()) return;
        Duration duration = (ttl != null && !ttl.isNegative() && !ttl.isZero()) ? ttl : Duration.ofMinutes(15);
        store.put(jti, Instant.now().plus(duration));
    }

    @Override
    public boolean isRevoked(String jti) {
        if (jti == null || jti.isBlank()) return false;
        Instant expiry = store.get(jti);
        if (expiry == null) {
            return false;
        }
        if (Instant.now().isAfter(expiry)) {
            store.remove(jti);
            return false;
        }
        return true;
    }

    public void clear() {
        store.clear();
    }
}
