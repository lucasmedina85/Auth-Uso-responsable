package com.authenticator.service;

import com.authenticator.domain.VerificationResult;
import org.springframework.stereotype.Service;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class VerificationSessionService {
    // In-memory mock storage: sessionId -> Result
    private final ConcurrentHashMap<String, VerificationResult> sessionStore = new ConcurrentHashMap<>();

    public void updateSessionStatus(String sessionId, VerificationResult result) {
        sessionStore.put(sessionId, result);
    }

    public VerificationResult getSessionStatus(String sessionId) {
        return sessionStore.get(sessionId);
    }
}
