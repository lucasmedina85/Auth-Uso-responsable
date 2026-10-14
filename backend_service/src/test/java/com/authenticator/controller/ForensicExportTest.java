package com.authenticator.controller;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.BlockchainTxStatus;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.security.ExportSigningKeyManager;
import com.authenticator.security.JwtUtil;
import com.authenticator.service.ForensicAuditService;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Map;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class ForensicExportTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ExportSigningKeyManager exportSigningKeyManager;

    @Autowired
    private ForensicAuditService forensicAuditService;

    @Autowired
    private BlockchainAuditLogRepository blockchainRepo;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    public void setUp() {
        blockchainRepo.deleteAll();
        BlockchainAuditLog log = new BlockchainAuditLog();
        log.setSessionId("session-id-forensic");
        log.setSessionHash("hash-session-test-forensic-" + UUID.randomUUID());
        log.setDecision("AUTORIZAR");
        log.setScore(10);
        log.setRiskConfigVersion("1.0.0");
        log.setBreakdownHash("breakdown-hash-test");
        log.setBreakdownDetailsJson("{}");
        log.setStatus(BlockchainTxStatus.CONFIRMED);
        log.setMaskedIp("198.51.***.***");
        log.setDniHash("dummy-hash");
        log.setCreatedAt(LocalDateTime.now());
        blockchainRepo.save(log);
    }

    @Test
    public void exportForensics_WithoutAuth_Returns401() throws Exception {
        mockMvc.perform(get("/admin/forensics/export"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void exportForensics_WithUserRole_Returns403() throws Exception {
        String userToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "USER");
        mockMvc.perform(get("/admin/forensics/export")
                .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isForbidden());
    }

    @Test
    public void exportForensics_WithAuditorRole_Returns200AndValidEncryptedBundle() throws Exception {
        String auditorToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "AUDITOR");

        MvcResult result = mockMvc.perform(get("/admin/forensics/export")
                .header("Authorization", "Bearer " + auditorToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.exportId").isString())
                .andExpect(jsonPath("$.enc_kid").isString())
                .andExpect(jsonPath("$.algorithm").value("AES-256-GCM"))
                .andExpect(jsonPath("$.iv").isString())
                .andExpect(jsonPath("$.ciphertext").isString())
                .andExpect(jsonPath("$.integrityHashSha256").isString())
                .andExpect(jsonPath("$.signature").isString())
                .andExpect(jsonPath("$.signingAlgorithm").value("SHA256withRSA"))
                .andExpect(jsonPath("$.keyId").value(exportSigningKeyManager.getPrimaryKeyId()))
                .andReturn();

        String responseBody = result.getResponse().getContentAsString();
        Map<String, Object> exportBundle = objectMapper.readValue(responseBody, new TypeReference<Map<String, Object>>() {});

        // Descifrado y verificación
        String decryptedJson = forensicAuditService.decryptAndVerify(exportBundle);
        assertNotNull(decryptedJson);
        assertTrue(decryptedJson.contains("totalBlockchainRecords"));
        assertTrue(decryptedJson.contains("session-id-forensic"));
    }

    @Test
    public void exportForensics_TamperingCiphertext_FailsIntegrityAndDecryption() throws Exception {
        String auditorToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "AUDITOR");

        MvcResult result = mockMvc.perform(get("/admin/forensics/export")
                .header("Authorization", "Bearer " + auditorToken))
                .andExpect(status().isOk())
                .andReturn();

        Map<String, Object> exportBundle = objectMapper.readValue(result.getResponse().getContentAsString(), new TypeReference<Map<String, Object>>() {});

        // Alterar 1 byte del ciphertext en Base64
        String rawCiphertext = (String) exportBundle.get("ciphertext");
        byte[] bytes = Base64.getDecoder().decode(rawCiphertext);
        bytes[0] = (byte) (bytes[0] ^ 0xFF); // invertir 1 byte
        exportBundle.put("ciphertext", Base64.getEncoder().encodeToString(bytes));

        // Debe fallar verificación / descifrado
        assertThrows(Exception.class, () -> forensicAuditService.decryptAndVerify(exportBundle));
    }

    @Test
    public void exportForensics_TamperingMetadata_FailsIntegrityAndAadValidation() throws Exception {
        String auditorToken = jwtUtil.generateAccessToken(UUID.randomUUID().toString(), "AUDITOR");

        MvcResult result = mockMvc.perform(get("/admin/forensics/export")
                .header("Authorization", "Bearer " + auditorToken))
                .andExpect(status().isOk())
                .andReturn();

        Map<String, Object> exportBundle = objectMapper.readValue(result.getResponse().getContentAsString(), new TypeReference<Map<String, Object>>() {});

        // Alterar metadatos (AAD)
        @SuppressWarnings("unchecked")
        Map<String, Object> meta = (Map<String, Object>) exportBundle.get("metadata");
        meta.put("algorithm", "AES-128-CBC");

        // Debe fallar verificación / descifrado AAD
        assertThrows(Exception.class, () -> forensicAuditService.decryptAndVerify(exportBundle));
    }
}
