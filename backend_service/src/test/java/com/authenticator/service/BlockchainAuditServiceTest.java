package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.repository.BlockchainAuditLogRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.Collections;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class BlockchainAuditServiceTest {

    @Autowired
    private BlockchainAuditService auditService;

    @Autowired
    private BlockchainAuditLogRepository auditLogRepository;

    @Autowired
    private MockBlockchainProvider mockProvider;

    @BeforeEach
    public void setUp() {
        auditLogRepository.deleteAll();
        mockProvider.resetToDefaults();
    }

    private RiskScoreBreakdown createSampleBreakdown(RiskDecision decision, int score) {
        return RiskScoreBreakdown.builder()
                .compositeScore(score)
                .decision(decision)
                .evaluatedAt(java.time.LocalDateTime.now())
                .hardRuleApplied(decision == RiskDecision.BLOQUEAR ? "EMULATOR_HARD_RULE" : null)
                .factorContributions(Collections.emptyMap())
                .factorStatus(Collections.emptyMap())
                .build();
    }

    @Test
    public void computeSessionHmac_CalculatesDeterministicHmac() {
        String session1 = "session-12345";
        String hmac1 = auditService.computeSessionHmac(session1);
        String hmac2 = auditService.computeSessionHmac(session1);

        assertNotNull(hmac1);
        assertEquals(64, hmac1.length(), "HMAC-SHA256 hex string should be 64 characters");
        assertEquals(hmac1, hmac2, "HMAC must be deterministic for same session and secret");

        String diffHmac = auditService.computeSessionHmac("session-67890");
        assertNotEquals(hmac1, diffHmac);
    }

    @Test
    public void computeSessionHmac_ThrowsWhenSecretMissing() {
        // Guardar secreto actual
        Object originalSecret = ReflectionTestUtils.getField(auditService, "sessionHashSecret");
        try {
            ReflectionTestUtils.setField(auditService, "sessionHashSecret", null);
            assertThrows(IllegalStateException.class, () -> auditService.computeSessionHmac("session-xyz"));

            ReflectionTestUtils.setField(auditService, "sessionHashSecret", "   ");
            assertThrows(IllegalStateException.class, () -> auditService.computeSessionHmac("session-xyz"));
        } finally {
            ReflectionTestUtils.setField(auditService, "sessionHashSecret", originalSecret);
        }
    }

    @Test
    public void computeSha256_ComputesCorrectDigest() {
        String input = "{\"score\":75,\"decision\":\"REVISIÓN\"}";
        String hash = auditService.computeSha256(input);

        assertNotNull(hash);
        assertEquals(64, hash.length());
        assertEquals(hash, auditService.computeSha256(input));
    }

    @Test
    public void queueRiskAssessment_SavesPendingRecordWithOnChainMinimalAndOffChainJson() {
        String sessionId = UUID.randomUUID().toString();
        RiskScoreBreakdown breakdown = createSampleBreakdown(RiskDecision.AUTORIZAR, 25);

        BlockchainAuditLog log = auditService.queueRiskAssessment(sessionId, RiskDecision.AUTORIZAR, 25, breakdown);

        assertNotNull(log);
        assertNotNull(log.getId());
        assertEquals(sessionId, log.getSessionId());
        assertEquals(auditService.computeSessionHmac(sessionId), log.getSessionHash());
        assertEquals(RiskDecision.AUTORIZAR.name(), log.getDecision());
        assertEquals(25, log.getScore());
        assertEquals("1.0.0", log.getRiskConfigVersion());
        assertNotNull(log.getBreakdownHash());
        assertNotNull(log.getBreakdownDetailsJson());
        assertTrue(log.getBreakdownDetailsJson().contains("\"compositeScore\":25"));
        assertEquals(0, log.getRetryCount());
    }

    @Test
    public void queueRiskAssessment_Idempotency_ReturnsExistingLogWithoutDuplication() {
        String sessionId = UUID.randomUUID().toString();
        RiskScoreBreakdown breakdown = createSampleBreakdown(RiskDecision.BLOQUEAR, 100);

        BlockchainAuditLog log1 = auditService.queueRiskAssessment(sessionId, RiskDecision.BLOQUEAR, 100, breakdown);
        BlockchainAuditLog log2 = auditService.queueRiskAssessment(sessionId, RiskDecision.BLOQUEAR, 100, breakdown);

        assertNotNull(log1);
        assertNotNull(log2);
        assertEquals(log1.getId(), log2.getId(), "Must return same record on duplicate submission");

        long count = auditLogRepository.count();
        assertEquals(1, count, "Database must contain exactly 1 log due to idempotency");
    }

    @Test
    public void processPendingRecord_WhenConsensusHealthy_ConfirmsRecordOnChain() {
        String sessionId = UUID.randomUUID().toString();
        RiskScoreBreakdown breakdown = createSampleBreakdown(RiskDecision.REVISIÓN, 65);
        BlockchainAuditLog log = auditService.queueRiskAssessment(sessionId, RiskDecision.REVISIÓN, 65, breakdown);

        // Ejecutar procesamiento sincrónico para la prueba
        auditService.processPendingRecord(log.getId());

        BlockchainAuditLog confirmed = auditLogRepository.findById(log.getId()).orElseThrow();
        assertEquals(BlockchainTxStatus.CONFIRMED, confirmed.getStatus());
        assertNotNull(confirmed.getTransactionHash());
        assertTrue(confirmed.getTransactionHash().startsWith("0x"));
        assertNotNull(confirmed.getConfirmedAt());
        assertNull(confirmed.getErrorMessage());
    }

    @Test
    public void processPendingRecord_WhenNoConsensus_LeavesPendingWithoutConsumingRetries() {
        // Simular desfase de consenso de red (CU-0031)
        mockProvider.setSimulateOutOfSync(true, 1_000_000L, 1_000_050L);

        String sessionId = UUID.randomUUID().toString();
        RiskScoreBreakdown breakdown = createSampleBreakdown(RiskDecision.BLOQUEAR, 85);
        BlockchainAuditLog log = auditService.queueRiskAssessment(sessionId, RiskDecision.BLOQUEAR, 85, breakdown);

        auditService.processPendingRecord(log.getId());

        BlockchainAuditLog unconfirmed = auditLogRepository.findById(log.getId()).orElseThrow();
        assertEquals(BlockchainTxStatus.PENDING, unconfirmed.getStatus(), "Must remain PENDING");
        assertEquals(0, unconfirmed.getRetryCount(), "Must NOT consume retries when consensus fails");
        assertNull(unconfirmed.getTransactionHash());
    }

    @Test
    public void processPendingRecord_SubmitFailure_RetriesAndTransitionsToFailedWhenMaxRetriesExceeded() {
        mockProvider.setSimulateSubmitFailure(true);

        String sessionId = UUID.randomUUID().toString();
        RiskScoreBreakdown breakdown = createSampleBreakdown(RiskDecision.BLOQUEAR, 90);
        BlockchainAuditLog log = auditService.queueRiskAssessment(sessionId, RiskDecision.BLOQUEAR, 90, breakdown);

        // Intento 1: falla -> PENDING, retryCount = 1
        auditService.processPendingRecord(log.getId());
        BlockchainAuditLog attempt1 = auditLogRepository.findById(log.getId()).orElseThrow();
        assertEquals(BlockchainTxStatus.PENDING, attempt1.getStatus());
        assertEquals(1, attempt1.getRetryCount());
        assertNotNull(attempt1.getErrorMessage());

        // Intento 2: falla -> PENDING, retryCount = 2
        auditService.processPendingRecord(log.getId());
        BlockchainAuditLog attempt2 = auditLogRepository.findById(log.getId()).orElseThrow();
        assertEquals(BlockchainTxStatus.PENDING, attempt2.getStatus());
        assertEquals(2, attempt2.getRetryCount());

        // Intento 3 (maxRetries = 3): falla -> FAILED, retryCount = 3
        auditService.processPendingRecord(log.getId());
        BlockchainAuditLog attempt3 = auditLogRepository.findById(log.getId()).orElseThrow();
        assertEquals(BlockchainTxStatus.FAILED, attempt3.getStatus());
        assertEquals(3, attempt3.getRetryCount());
        assertTrue(attempt3.getErrorMessage().contains("reverted"));
    }

    @Test
    public void retryPendingQueue_ProcessesAllPendingWhenConsensusHealthy() {
        // Encolar 2 registros
        String s1 = UUID.randomUUID().toString();
        String s2 = UUID.randomUUID().toString();
        BlockchainAuditLog log1 = auditService.queueRiskAssessment(s1, RiskDecision.AUTORIZAR, 10, createSampleBreakdown(RiskDecision.AUTORIZAR, 10));
        BlockchainAuditLog log2 = auditService.queueRiskAssessment(s2, RiskDecision.BLOQUEAR, 95, createSampleBreakdown(RiskDecision.BLOQUEAR, 95));

        // Correr scheduler
        auditService.retryPendingQueue();

        assertEquals(BlockchainTxStatus.CONFIRMED, auditLogRepository.findById(log1.getId()).get().getStatus());
        assertEquals(BlockchainTxStatus.CONFIRMED, auditLogRepository.findById(log2.getId()).get().getStatus());
    }

    @Test
    public void retryPendingQueue_SkipsProcessingWhenNetworkOutOfSync() {
        mockProvider.setSimulateOutOfSync(true, 500L, 600L);

        String s1 = UUID.randomUUID().toString();
        BlockchainAuditLog log1 = auditService.queueRiskAssessment(s1, RiskDecision.AUTORIZAR, 15, createSampleBreakdown(RiskDecision.AUTORIZAR, 15));

        auditService.retryPendingQueue();

        assertEquals(BlockchainTxStatus.PENDING, auditLogRepository.findById(log1.getId()).get().getStatus());
        assertEquals(0, auditLogRepository.findById(log1.getId()).get().getRetryCount());
    }
}
