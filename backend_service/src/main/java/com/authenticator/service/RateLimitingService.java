package com.authenticator.service;

import org.springframework.stereotype.Service;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.scheduling.annotation.EnableScheduling;

import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
@EnableScheduling
public class RateLimitingService {
    private final Map<String, TokenBucket> cache = new ConcurrentHashMap<>();

    public boolean tryConsume(String key) {
        TokenBucket bucket = cache.computeIfAbsent(key, k -> new TokenBucket(5, 15 * 60)); // 5 req per 15 min
        return bucket.tryConsume();
    }

    @Scheduled(fixedRate = 900000) // 15 minutes
    public void cleanup() {
        long now = Instant.now().getEpochSecond();
        cache.entrySet().removeIf(entry -> 
            (now - entry.getValue().lastRefillTimestamp) > 15 * 60
        );
    }

    private static class TokenBucket {
        private final int capacity;
        private final long refillPeriodSeconds;
        private int tokens;
        private long lastRefillTimestamp;

        public TokenBucket(int capacity, long refillPeriodSeconds) {
            this.capacity = capacity;
            this.refillPeriodSeconds = refillPeriodSeconds;
            this.tokens = capacity;
            this.lastRefillTimestamp = Instant.now().getEpochSecond();
        }

        public synchronized boolean tryConsume() {
            refill();
            if (tokens > 0) {
                tokens--;
                return true;
            }
            return false;
        }

        private void refill() {
            long now = Instant.now().getEpochSecond();
            long elapsed = now - lastRefillTimestamp;
            if (elapsed >= refillPeriodSeconds) {
                int tokensToAdd = (int) (elapsed / refillPeriodSeconds) * capacity;
                tokens = Math.min(capacity, tokens + tokensToAdd);
                lastRefillTimestamp = now;
            }
        }
    }
}
