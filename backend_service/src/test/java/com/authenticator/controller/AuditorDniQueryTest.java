package com.authenticator.controller;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.BlockchainTxStatus;
import com.authenticator.domain.OAuthAuditLog;
import com.authenticator.dto.AuditorDniQueryRequest;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.security.JwtUtil;
import com.authenticator.service.BlockchainAuditService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.hasSize;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class AuditorDniQueryTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private BlockchainAuditService blockchainAuditService;

    @Autowired
    private BlockchainAuditLogRepository blockchainRepo;

    @Autowired
    private OAuthAuditLogRepository oauthAuditRepo;

    @Autowired
    private ObjectMapper objectMapper;

    private final String rawDni = "40123456";
    private String rawDniHash;

    @BeforeEach
    public void setUp() {
        oauthAuditRepo.deleteAll();
        blockchainRepo.deleteAll();

        rawDniHash = blockchainAuditService.computeSha256(rawDni);
        String dniSearchHash = blockchainAuditService.computeDniSearchHash(rawDniHash);

        BlockchainAuditLog log1 = new BlockchainAuditLog();
        log1.setSessionId("session-auditor-1");
        log1.setSessionHash("session-hash-1");
        log1.setDecision("AUTORIZAR");
        log1.setScore(12);
        log1.setRiskConfigVersion("1.0.0");
        log1.setBreakdownHash("breakdown-hash-auditor");
        log1.setBreakdownDetailsJson("{}");
        log1.setStatus(BlockchainTxStatus.CONFIRMED);
        log1.setMaskedIp("198.51.***.***");
        log1.setDniHash(rawDniHash);
        log1.setDniSearchHash(dniSearchHash);
        log1.setCreatedAt(LocalDateTime.now());
        blockchainRepo.save(log1);
    }

    @Test
    public void queryByDni_WithoutAuth_Returns401() throws Exception {
        AuditorDniQueryRequest req = new AuditorDniQueryRequest(rawDni, "Motivo válido de investigación forense");

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void queryByDni_WithUserRole_Returns403() throws Exception {
        String userToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "USER");
        AuditorDniQueryRequest req = new AuditorDniQueryRequest(rawDni, "Motivo válido de investigación forense");

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .header("Authorization", "Bearer " + userToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    public void queryByDni_WithInvalidReasonLength_Returns400() throws Exception {
        String auditorToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "AUDITOR");
        AuditorDniQueryRequest req = new AuditorDniQueryRequest(rawDni, "Corto"); // < 10 caracteres

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .header("Authorization", "Bearer " + auditorToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest());
    }

    @Test
    public void queryByDni_WithBlankDni_Returns400() throws Exception {
        String auditorToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "AUDITOR");
        AuditorDniQueryRequest req = new AuditorDniQueryRequest("", "Motivo válido de investigación forense");

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .header("Authorization", "Bearer " + auditorToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest());
    }

    @Test
    public void queryByDni_WithAuditorRole_Returns200AndRecordsAndLogsAuditWithoutRawDni() throws Exception {
        String auditorId = UUID.randomUUID().toString();
        String auditorToken = jwtUtil.generateAccessToken(auditorId, "AUDITOR");
        AuditorDniQueryRequest req = new AuditorDniQueryRequest(rawDni, "Investigación judicial causa 102/2026");

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .header("Authorization", "Bearer " + auditorToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].sessionHash").value("session-hash-1"))
                .andExpect(jsonPath("$[0].decision").value("AUTORIZAR"))
                .andExpect(jsonPath("$[0].maskedIp").value("198.51.***.***"));

        // Verificar que la consulta del auditor quedó asentada en la auditoría sin exponer el DNI en claro
        List<OAuthAuditLog> auditLogs = oauthAuditRepo.findAll();
        assertFalse(auditLogs.isEmpty());
        OAuthAuditLog queryLog = auditLogs.stream()
                .filter(l -> "AUDITOR_QUERY".equals(l.getEventType()))
                .findFirst()
                .orElse(null);
        assertNotNull(queryLog);
        assertEquals("INTERNAL_AUDIT", queryLog.getClientId());
        assertTrue(queryLog.getDetails().contains("Investigación judicial causa 102/2026"));
        assertTrue(queryLog.getDetails().contains(auditorId));
        // El DNI en claro nunca debe constar en details ni logs
        assertFalse(queryLog.getDetails().contains(rawDni));
        assertEquals(blockchainAuditService.computeDniSearchHash(rawDniHash), queryLog.getUserIdHash());
    }

    @Test
    public void queryByDni_WithAdminRole_Returns200() throws Exception {
        String adminToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "ADMIN");
        AuditorDniQueryRequest req = new AuditorDniQueryRequest(rawDni, "Auditoría interna de rutina autorizada");

        mockMvc.perform(post("/admin/blockchain/records-by-dni")
                .header("Authorization", "Bearer " + adminToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)));
    }
}
