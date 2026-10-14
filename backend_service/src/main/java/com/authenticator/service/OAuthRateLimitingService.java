package com.authenticator.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class OAuthRateLimitingService {

    @Value("${app.oauth.rate-limit.max-requests-per-minute:30}")
    private int maxRequestsPerMinute;

    @Value("${app.oauth.rate-limit.client-secret-max-failures:5}")
    private int maxClientSecretFailures;

    @Value("${app.oauth.rate-limit.client-secret-lockout-seconds:300}")
    private int lockoutDurationSeconds;

    // IP Rate Limiting: IP -> RequestCounter
    private static class RequestBucket {
        long windowStartTimestamp;
        AtomicInteger count;

        RequestBucket(long timestamp) {
            this.windowStartTimestamp = timestamp;
            this.count = new AtomicInteger(1);
        }
    }

    // Client Secret Lockout: ClientId -> LockoutStatus
    private static class ClientLockout {
        AtomicInteger failures = new AtomicInteger(0);
        volatile long lockedUntil = 0;
    }

    private final ConcurrentHashMap<String, RequestBucket> ipBuckets = new ConcurrentHashMap<>();
    private final ConcurrentHashMap<String, ClientLockout> clientLockouts = new ConcurrentHashMap<>();

    public boolean checkRequestRateLimit(String ipKey) {
        long now = Instant.now().getEpochSecond();
        ipBuckets.compute(ipKey, (k, bucket) -> {
            if (bucket == null || (now - bucket.windowStartTimestamp) >= 60) {
                return new RequestBucket(now);
            }
            bucket.count.incrementAndGet();
            return bucket;
        });

        RequestBucket current = ipBuckets.get(ipKey);
        return current != null && current.count.get() <= maxRequestsPerMinute;
    }

    public boolean isClientLocked(String clientId) {
        ClientLockout lockout = clientLockouts.get(clientId);
        if (lockout == null) {
            return false;
        }
        long now = Instant.now().getEpochSecond();
        if (lockout.lockedUntil > now) {
            return true;
        }
        if (lockout.lockedUntil > 0 && lockout.lockedUntil <= now) {
            // Lock expired
            lockout.lockedUntil = 0;
            lockout.failures.set(0);
        }
        return false;
    }

    public long getRemainingLockoutSeconds(String clientId) {
        ClientLockout lockout = clientLockouts.get(clientId);
        if (lockout == null) {
            return 0;
        }
        long now = Instant.now().getEpochSecond();
        long diff = lockout.lockedUntil - now;
        return Math.max(0, diff);
    }

    public void recordClientSecretFailure(String clientId) {
        ClientLockout lockout = clientLockouts.computeIfAbsent(clientId, k -> new ClientLockout());
        int failedAttempts = lockout.failures.incrementAndGet();
        if (failedAttempts >= maxClientSecretFailures) {
            long now = Instant.now().getEpochSecond();
            lockout.lockedUntil = now + lockoutDurationSeconds;
        }
    }

    public void recordClientSecretSuccess(String clientId) {
        clientLockouts.remove(clientId);
    }

    public void resetForTests() {
        ipBuckets.clear();
        clientLockouts.clear();
    }
}
