package com.authenticator.controller;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.BlockchainNetworkStatus;
import com.authenticator.domain.OAuthAuditLog;
import com.authenticator.dto.AuditorDniQueryRequest;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.service.BlockchainAuditService;
import com.authenticator.service.BlockchainConsensusService;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Controladores de Consenso de Red Blockchain y Consultas Forenses (CU-0031, CU-0047).
 *
 * 1. GET /blockchain/status: Endpoint público mínimo (UP/DOWN con 200/503) sin exponer detalles internos.
 * 2. GET /admin/blockchain/status: Endpoint protegido para supervisores/administradores con métricas completas.
 * 3. POST /admin/blockchain/records-by-dni: Endpoint protegido para AUDITOR/ADMIN para consultar registros por DNI (CU-0047).
 */
@RestController
public class BlockchainStatusController {

    private static final Logger log = LoggerFactory.getLogger(BlockchainStatusController.class);

    private final BlockchainConsensusService consensusService;
    private final BlockchainAuditService blockchainAuditService;
    private final OAuthAuditLogRepository auditLogRepository;

    @Value("${app.blockchain.auditor-rate-limit.max-requests-per-minute:10}")
    private int maxAuditorRequestsPerMinute = 10;

    private final Map<String, List<Long>> auditorRequestTimestamps = new ConcurrentHashMap<>();

    public BlockchainStatusController(BlockchainConsensusService consensusService,
                                      BlockchainAuditService blockchainAuditService,
                                      OAuthAuditLogRepository auditLogRepository) {
        this.consensusService = consensusService;
        this.blockchainAuditService = blockchainAuditService;
        this.auditLogRepository = auditLogRepository;
    }

    /**
     * Endpoint público mínimo: {"status": "UP"} o {"status": "DOWN"}.
     * Oculta alturas de bloque, cantidad de peers e información topológica interna.
     */
    @GetMapping("/blockchain/status")
    public ResponseEntity<Map<String, String>> getPublicStatus() {
        boolean healthy = consensusService.isConsensusHealthy();
        if (healthy) {
            return ResponseEntity.ok(Map.of("status", "UP"));
        } else {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Map.of("status", "DOWN"));
        }
    }

    /**
     * Endpoint administrativo protegido (requiere ROLE_ADMIN o ROLE_MONITORING).
     * Provee desglose forense completo: altura local, pares conectados, sincronización y diagnóstico.
     */
    @GetMapping("/admin/blockchain/status")
    public ResponseEntity<BlockchainNetworkStatus> getAdminStatus() {
        BlockchainNetworkStatus status = consensusService.checkConsensus();
        if (status.isConsensusReached()) {
            return ResponseEntity.ok(status);
        } else {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(status);
        }
    }

    /**
     * Endpoint administrativo/auditor protegido (requiere ROLE_ADMIN o ROLE_AUDITOR).
     * Consulta registros forenses off-chain por DNI mediante POST (CU-0047).
     * Calcula ambos hashes internamente en el backend, exige motivo obligatorio (mínimo 10 caracteres),
     * aplica rate limiting por auditor y registra la consulta sin volcar el DNI en claro en ningún log.
     */
    @PostMapping("/admin/blockchain/records-by-dni")
    public ResponseEntity<?> getRecordsByDni(@Valid @RequestBody AuditorDniQueryRequest request,
                                            Authentication authentication) {
        String auditorIdentifier = (authentication != null && authentication.getName() != null)
                ? authentication.getName()
                : "UNKNOWN_AUDITOR";

        if (request.getReason() == null || request.getReason().trim().length() < 10) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", "invalid_reason",
                "message", "El motivo de la consulta es obligatorio y debe tener al menos 10 caracteres"
            ));
        }

        if (request.getDni() == null || request.getDni().trim().isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", "invalid_dni",
                "message", "El DNI es obligatorio"
            ));
        }

        if (!checkAuditorRateLimit(auditorIdentifier)) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS).body(Map.of(
                "error", "too_many_requests",
                "message", "Límite de consultas de auditoría por minuto excedido. Reintente en un momento."
            ));
        }

        String rawDni = request.getDni().trim();
        String dniHash = blockchainAuditService.computeSha256(rawDni);

        // Registrar consulta del auditor en auditoría (CU-0047) - NUNCA el DNI en claro
        OAuthAuditLog auditLog = new OAuthAuditLog();
        auditLog.setEventType("AUDITOR_QUERY");
        auditLog.setClientId("INTERNAL_AUDIT");
        auditLog.setUserIdHash(blockchainAuditService.computeDniSearchHash(dniHash));
        auditLog.setDetails("Consulta de registros blockchain por DNI efectuada por auditor: " + auditorIdentifier + " | Motivo: " + request.getReason().trim());
        auditLogRepository.save(auditLog);

        log.info("Consulta auditor por DNI procesada para auditorId={}, motivo={}", auditorIdentifier, request.getReason().trim());

        List<BlockchainAuditLog> logs = blockchainAuditService.findRecordsByDni(dniHash);
        if (logs.isEmpty()) {
            // Compatibilidad por si el log previo fue indexado usando el string directo
            logs = blockchainAuditService.findRecordsByDni(rawDni);
        }

        return ResponseEntity.ok(logs);
    }

    private boolean checkAuditorRateLimit(String auditorId) {
        long now = System.currentTimeMillis();
        long windowStart = now - 60_000L;
        List<Long> timestamps = auditorRequestTimestamps.compute(auditorId, (k, v) -> {
            List<Long> updated = (v == null) ? new ArrayList<>() : new ArrayList<>(v);
            updated.removeIf(t -> t < windowStart);
            updated.add(now);
            return updated;
        });
        return timestamps.size() <= maxAuditorRequestsPerMinute;
    }
}
