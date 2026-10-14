package com.authenticator.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Component;

import java.time.Duration;

@Component
@ConditionalOnProperty(name = "app.revocation.store", havingValue = "redis")
public class RedisRevocationStore implements RevocationStore {

    private static final Logger log = LoggerFactory.getLogger(RedisRevocationStore.class);
    private static final String KEY_PREFIX = "revoked:";

    private final StringRedisTemplate redisTemplate;

    public RedisRevocationStore(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    @Override
    public void revoke(String jti, Duration ttl) {
        if (jti == null || jti.isBlank()) return;
        Duration duration = (ttl != null && !ttl.isNegative() && !ttl.isZero()) ? ttl : Duration.ofMinutes(15);
        try {
            redisTemplate.opsForValue().set(KEY_PREFIX + jti, "1", duration);
        } catch (Exception e) {
            log.error("Fallo al escribir en Redis para revocar jti {}: {}. Modo degradado activado.", jti, e.getMessage());
            throw new RuntimeException("Redis error while storing revoked token", e);
        }
    }

    @Override
    public boolean isRevoked(String jti) {
        if (jti == null || jti.isBlank()) return false;
        try {
            Boolean exists = redisTemplate.hasKey(KEY_PREFIX + jti);
            return Boolean.TRUE.equals(exists);
        } catch (Exception e) {
            log.warn("Redis no disponible al verificar jti {}: {}. Se delega a fallback.", jti, e.getMessage());
            throw new RuntimeException("Redis unreachable during revocation check", e);
        }
    }
}
