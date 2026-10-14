package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

/**
 * Servicio de Registro de Auditoría en Blockchain (CU-0030 / CU-0047).
 *
 * Responsable de certificar las decisiones del Motor de Riesgo (CU-0023):
 * - Guarda on-chain únicamente: sessionHash (HMAC-SHA256), decisión, score, configVersion, timestamp y breakdownHash (SHA-256).
 * - Guarda off-chain (BD): desglose probatorio estructurado en formato JSON.
 * - Idempotencia: previene registros duplicados para la misma sesión y decisión.
 * - Resiliencia no bloqueante: la inserción se desacopla mediante persistencia en estado PENDING y despacho asíncrono post-commit.
 * - Consenso de Red (CU-0031): comprueba salud y sincronización de red antes del envío, sin consumir reintentos si la red no alcanza consenso.
 */
@Service
public class BlockchainAuditService {

    private static final Logger logger = LoggerFactory.getLogger(BlockchainAuditService.class);

    private final BlockchainAuditLogRepository auditLogRepository;
    private final BlockchainProvider blockchainProvider;
    private final BlockchainConsensusService consensusService;
    private final ObjectMapper objectMapper;

    @Value("${app.blockchain.enabled:true}")
    private boolean enabled = true;

    @Value("${app.blockchain.config-version:1.0.0}")
    private String configVersion = "1.0.0";

    @Value("${app.blockchain.session-hash-secret:${SESSION_HASH_SECRET:}}")
    private String sessionHashSecret;

    @Value("${app.blockchain.dni-search-secret:${DNI_SEARCH_SECRET:}}")
    private String dniSearchSecret;

    @Value("${app.blockchain.max-retries:3}")
    private int maxRetries = 3;

    public BlockchainAuditService(
            BlockchainAuditLogRepository auditLogRepository,
            @Autowired(required = false) BlockchainProvider blockchainProvider,
            BlockchainConsensusService consensusService,
            ObjectMapper objectMapper) {
        this.auditLogRepository = auditLogRepository;
        this.blockchainProvider = blockchainProvider;
        this.consensusService = consensusService;
        this.objectMapper = objectMapper;
    }

    /**
     * Encola una decisión del Motor de Riesgo para auditoría Blockchain (CU-0030 / CU-0047).
     * Versión compatible hacia atrás.
     */
    @Transactional
    public BlockchainAuditLog queueRiskAssessment(
            String sessionId,
            RiskDecision decision,
            int score,
            RiskScoreBreakdown breakdown) {
        return queueRiskAssessment(sessionId, decision, score, breakdown, null, null);
    }

    /**
     * Encola una decisión enriquecida con IP enmascarada y hash de DNI para trazabilidad off-chain (CU-0029 / CU-0047).
     */
    @Transactional
    public BlockchainAuditLog queueRiskAssessment(
            String sessionId,
            RiskDecision decision,
            int score,
            RiskScoreBreakdown breakdown,
            String maskedIp,
            String dniHash) {

        if (!enabled) {
            logger.info("Registro de Blockchain deshabilitado por configuración");
            return null;
        }

        String sessionHash = computeSessionHmac(sessionId);
        String breakdownJson = serializeBreakdown(breakdown);
        String breakdownHash = computeSha256(breakdownJson);
        String dniSearchHash = (dniHash != null && !dniHash.isBlank()) ? computeDniSearchHash(dniHash) : null;

        // Idempotencia: Si ya existe un registro para esta sesión y decisión, retornarlo sin duplicar
        Optional<BlockchainAuditLog> existing = auditLogRepository.findBySessionHashAndDecision(sessionHash, decision.name());
        if (existing.isPresent()) {
            logger.info("Registro de auditoría ya existente para sesión {} y decisión {}. Idempotencia preservada.",
                    sessionHash, decision.name());
            return existing.get();
        }

        BlockchainAuditLog auditLog = BlockchainAuditLog.builder()
                .sessionId(sessionId)
                .sessionHash(sessionHash)
                .decision(decision.name())
                .score(score)
                .riskConfigVersion(configVersion)
                .breakdownHash(breakdownHash)
                .breakdownDetailsJson(breakdownJson)
                .status(BlockchainTxStatus.PENDING)
                .retryCount(0)
                .maskedIp(maskedIp)
                .dniHash(dniHash)
                .dniSearchHash(dniSearchHash)
                .createdAt(LocalDateTime.now())
                .build();

        BlockchainAuditLog savedLog;
        try {
            savedLog = auditLogRepository.save(auditLog);
        } catch (DataIntegrityViolationException e) {
            // Manejo de carrera concurrente con índice único (session_hash, decision)
            logger.warn("Conflicto de unicidad detectado para sesión {} y decisión {}. Recuperando existente.",
                    sessionHash, decision.name());
            return auditLogRepository.findBySessionHashAndDecision(sessionHash, decision.name())
                    .orElse(auditLog);
        }

        UUID logId = savedLog.getId();

        // Despacho asíncrono estrictamente DESPUÉS del commit de la transacción (Ajuste 5)
        if (TransactionSynchronizationManager.isActualTransactionActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    processPendingRecordAsync(logId);
                }
            });
        } else {
            processPendingRecordAsync(logId);
        }

        return savedLog;
    }

    /**
     * Despacho asíncrono hacia la Blockchain en pool dedicado sin bloquear el hilo HTTP.
     */
    @Async("blockchainTaskExecutor")
    public void processPendingRecordAsync(UUID logId) {
        try {
            processPendingRecord(logId);
        } catch (Exception e) {
            logger.error("Error no controlado en despacho asíncrono para log {}: {}", logId, e.getMessage());
        }
    }

    /**
     * Procesa un registro pendiente individual.
     * Consulta el consenso de red (CU-0031) antes de interactuar con la Blockchain.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void processPendingRecord(UUID logId) {
        Optional<BlockchainAuditLog> optLog = auditLogRepository.findById(logId);
        if (optLog.isEmpty()) {
            return;
        }

        BlockchainAuditLog log = optLog.get();
        if (log.getStatus() != BlockchainTxStatus.PENDING) {
            return;
        }

        // CU-0031: Verificar consenso de red antes del envío
        BlockchainNetworkStatus consensus = consensusService.checkConsensus();
        if (!consensus.isConsensusReached()) {
            // Regla clave: Si no hay consenso, dejar en PENDING SIN consumir reintentos (Ajuste 1)
            logger.warn("No se puede despachar registro {} a Blockchain: red sin consenso ({}: {}). Permanece en PENDING sin consumir reintentos.",
                    logId, consensus.getStatus(), consensus.getMessage());
            return;
        }

        if (blockchainProvider == null) {
            logger.warn("Proveedor de blockchain no disponible para procesar log {}", logId);
            return;
        }

        BlockchainRecord record = BlockchainRecord.builder()
                .sessionHash(log.getSessionHash())
                .decision(log.getDecision())
                .score(log.getScore())
                .riskConfigVersion(log.getRiskConfigVersion())
                .timestamp(log.getCreatedAt().atZone(ZoneId.systemDefault()).toInstant())
                .breakdownHash(log.getBreakdownHash())
                .build();

        try {
            BlockchainTxReceipt receipt = blockchainProvider.submitRiskAssessment(record);
            log.setStatus(BlockchainTxStatus.CONFIRMED);
            log.setTransactionHash(receipt.getTransactionHash());
            log.setConfirmedAt(LocalDateTime.now());
            log.setErrorMessage(null);
            auditLogRepository.save(log);
            logger.info("Registro de auditoría {} confirmado on-chain. TxHash: {}", logId, receipt.getTransactionHash());
        } catch (Exception e) {
            int newRetries = log.getRetryCount() + 1;
            log.setRetryCount(newRetries);
            log.setErrorMessage(e.getMessage());

            if (newRetries >= maxRetries) {
                // Ajuste 6: Superó límite de reintentos -> FAILED
                log.setStatus(BlockchainTxStatus.FAILED);
                logger.error("Registro {} superó el límite de reintentos ({}/{}). Marcado como FAILED. Error: {}",
                        logId, newRetries, maxRetries, e.getMessage());
            } else {
                log.setStatus(BlockchainTxStatus.PENDING);
                logger.warn("Error enviando log {} a Blockchain. Intento {}/{}. Permanece en PENDING. Causa: {}",
                        logId, newRetries, maxRetries, e.getMessage());
            }
            auditLogRepository.save(log);
        }
    }

    /**
     * Scheduler que barre la cola de pendientes y reintenta envíos (Ajuste 1 y 6).
     */
    @Scheduled(fixedDelayString = "${app.blockchain.retry-interval-ms:30000}")
    public void retryPendingQueue() {
        if (!enabled) {
            return;
        }

        BlockchainNetworkStatus consensus = consensusService.checkConsensus();
        if (!consensus.isConsensusReached()) {
            logger.debug("Scheduler de reintento suspendido: red blockchain sin consenso ({})", consensus.getStatus());
            return;
        }

        List<BlockchainAuditLog> pendingLogs = auditLogRepository.findTop20ByStatusOrderByCreatedAtAsc(BlockchainTxStatus.PENDING);
        if (pendingLogs.isEmpty()) {
            return;
        }

        logger.info("Scheduler procesando {} registros de auditoría pendientes...", pendingLogs.size());
        for (BlockchainAuditLog pendingLog : pendingLogs) {
            try {
                processPendingRecord(pendingLog.getId());
            } catch (Exception e) {
                logger.error("Fallo reintentando registro {}: {}", pendingLog.getId(), e.getMessage());
            }
        }
    }

    /**
     * Calcula HMAC-SHA256 para el identificador de sesión (Ajuste 3).
     */
    public String computeSessionHmac(String sessionId) {
        if (sessionHashSecret == null || sessionHashSecret.trim().isEmpty()) {
            throw new IllegalStateException("El secreto de sesión 'app.blockchain.session-hash-secret' (SESSION_HASH_SECRET) es obligatorio");
        }

        try {
            Mac hmac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(
                    sessionHashSecret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            hmac.init(secretKey);
            byte[] bytes = hmac.doFinal(sessionId.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(bytes);
        } catch (Exception e) {
            throw new RuntimeException("Error calculando HMAC-SHA256 de sesión", e);
        }
    }

    /**
     * Calcula SHA-256 canónico para el desglose probatorio (CU-0030).
     */
    public String computeSha256(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(hash);
        } catch (Exception e) {
            throw new RuntimeException("Error calculando SHA-256", e);
        }
    }

    private String serializeBreakdown(RiskScoreBreakdown breakdown) {
        try {
            if (breakdown == null) {
                return "{}";
            }
            return objectMapper.writeValueAsString(breakdown.toAuditMap());
        } catch (Exception e) {
            logger.error("Error serializando desglose de riesgo a JSON: {}", e.getMessage());
            return "{}";
        }
    }

    /**
     * Calcula HMAC-SHA256 con clave secreta dedicada para búsqueda auditada por DNI (CU-0047).
     * No expone el DNI en claro y permite búsqueda exacta indexada.
     */
    public String computeDniSearchHash(String dniHash) {
        if (dniHash == null || dniHash.trim().isEmpty()) {
            return null;
        }
        String secret = (dniSearchSecret != null && !dniSearchSecret.trim().isEmpty())
                ? dniSearchSecret
                : "test-dni-search-secret-fallback-key-for-auditing";
        try {
            Mac hmac = Mac.getInstance("HmacSHA256");
            SecretKeySpec secretKey = new SecretKeySpec(
                    secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            hmac.init(secretKey);
            byte[] bytes = hmac.doFinal(dniHash.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(bytes);
        } catch (Exception e) {
            throw new RuntimeException("Error calculando HMAC-SHA256 de búsqueda por DNI", e);
        }
    }

    /**
     * Consulta registros de blockchain off-chain asociados a un DNI por su hash seudónimo (CU-0047).
     */
    @Transactional(readOnly = true)
    public List<BlockchainAuditLog> findRecordsByDni(String dniHash) {
        if (dniHash == null || dniHash.isBlank()) {
            return List.of();
        }
        String searchHash = computeDniSearchHash(dniHash);
        return auditLogRepository.findByDniSearchHashOrderByCreatedAtDesc(searchHash);
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }
}
