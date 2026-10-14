package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.dto.SecurityScoreResponse;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
public class SecurityScoreServiceTest {

    @Autowired
    private SecurityScoreService scoreService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TrustedDeviceRepository deviceRepository;

    @Autowired
    private BlockchainAuditLogRepository auditLogRepository;

    private User user;

    @BeforeEach
    public void setup() {
        auditLogRepository.deleteAll();
        deviceRepository.deleteAll();
        userRepository.deleteAll();

        user = new User();
        user.setEmail("score@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);
    }

    @Test
    public void testBaseScore_UnverifiedUser_StartsLow() {
        SecurityScoreResponse resp = scoreService.calculateScore(user.getId(), false, false);
        // Base: 15, unverified: no identity points
        assertEquals(15, resp.getScore());
        assertEquals("BAJO", resp.getLevel());
    }

    @Test
    public void testUnverifiedUser_NeverReachesAltoConfidence() {
        // Even if client reports biometrics and has trusted devices
        TrustedDevice dev = TrustedDevice.builder()
                .user(user)
                .deviceHash("hash1")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        deviceRepository.save(dev);

        SecurityScoreResponse resp = scoreService.calculateScore(user.getId(), true, true);
        // Base 15 + Trusted 20 + Biometrics 5 = 40 <= 55 (unverifiedMaxScore)
        assertTrue(resp.getScore() <= 55);
        assertNotEquals("ALTO", resp.getLevel());
    }

    @Test
    public void testVerifiedUser_WithAuthorization_ReachesAlto() {
        user.setStatus(UserStatus.LOCALLY_VERIFIED);
        user.setDniHash("dnihash123");
        user = userRepository.save(user);

        // Add trusted device
        TrustedDevice dev = TrustedDevice.builder()
                .user(user)
                .deviceHash("hash1")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        deviceRepository.save(dev);

        // Add successful blockchain audit log
        BlockchainAuditLog log = BlockchainAuditLog.builder()
                .sessionId(UUID.randomUUID().toString())
                .sessionHash("sessionhash123")
                .decision("AUTORIZAR")
                .score(10)
                .riskConfigVersion("1.0.0")
                .breakdownHash("breakdownhash")
                .breakdownDetailsJson("{}")
                .dniHash("dnihash123")
                .build();
        auditLogRepository.save(log);

        SecurityScoreResponse resp = scoreService.calculateScore(user.getId(), true, true);
        // Base 15 + Identity 30 + Decision 20 + Device 20 + Biometrics 5 = 90
        assertEquals(90, resp.getScore());
        assertEquals("ALTO", resp.getLevel());
        assertEquals("Alta Confianza", resp.getLevelDescription());
        assertFalse(resp.getFactors().isEmpty());
    }

    @Test
    public void testRecentFailedAttempts_DeductsPoints() {
        user.setFailedLoginAttempts(3);
        user.setUpdatedAt(LocalDateTime.now());
        user = userRepository.save(user);

        SecurityScoreResponse resp = scoreService.calculateScore(user.getId(), false, false);
        // Base 15 - (3 * 5 = 15) = 0
        assertEquals(0, resp.getScore());
        assertEquals("BAJO", resp.getLevel());
    }

    @Test
    public void testRiskDecisionAutorizar_AddsTwentyPoints() {
        user.setStatus(UserStatus.REGISTERED);
        user.setDniHash("testdnihash");
        user = userRepository.save(user);

        // Before audit log: Base 15
        SecurityScoreResponse beforeResp = scoreService.calculateScore(user.getId(), false, false);
        assertEquals(15, beforeResp.getScore());

        // Save log with RiskDecision.AUTORIZAR
        BlockchainAuditLog log = BlockchainAuditLog.builder()
                .sessionId(UUID.randomUUID().toString())
                .sessionHash("sessionhash123")
                .decision(RiskDecision.AUTORIZAR.name())
                .score(10)
                .riskConfigVersion("1.0.0")
                .breakdownHash("breakdownhash")
                .breakdownDetailsJson("{}")
                .dniHash("testdnihash")
                .build();
        auditLogRepository.save(log);

        SecurityScoreResponse afterResp = scoreService.calculateScore(user.getId(), false, false);
        // Base 15 + Decision 20 = 35
        assertEquals(35, afterResp.getScore());
        assertTrue(afterResp.getFactors().stream().anyMatch(f ->
                "Evaluación de Seguridad Operacional".equals(f.getName()) && f.getContribution() == 20));
    }
}
