package com.authenticator.controller;

import com.authenticator.domain.BlockchainAuditLog;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.RefreshTokenRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class VerificationLocalControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private BlockchainAuditLogRepository auditLogRepository;

    @BeforeEach
    public void setup() {
        auditLogRepository.deleteAll();
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    public void informLocalResult_ValidToken_UpdatesUserStatus() throws Exception {
        User user = new User();
        user.setEmail("verify@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // CU-0023: Con señales legítimas de alta confianza, el score es bajo y autoriza
        String requestBody = "{\"dniHash\":\"some-hash\",\"livenessScore\":98,\"faceMatchScore\":95,\"isLatestDocument\":true}";

        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.status").value("OK"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.decision").value("AUTORIZAR"));

        User updated = userRepository.findById(user.getId()).get();
        assertEquals(UserStatus.LOCALLY_VERIFIED, updated.getStatus());
        assertEquals("some-hash", updated.getDniHash());

        // CU-0030: Registro de Auditoría en Blockchain para AUTORIZAR
        assertEquals(1, auditLogRepository.count());
        BlockchainAuditLog log = auditLogRepository.findAll().get(0);
        assertEquals("AUTORIZAR", log.getDecision());
        assertTrue(log.getSessionId().startsWith(user.getId().toString() + ":"));
    }

    @Test
    public void informLocalResult_UnderReview_Returns200WithUnderReviewStatus() throws Exception {
        User user = new User();
        user.setEmail("review@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // liveness 60 (contribución 40) + faceMatch 85 (contribución 15) = 55 (REVISIÓN entre 50 y 79)
        String requestBody = "{\"dniHash\":\"review-hash\",\"livenessScore\":60,\"faceMatchScore\":85,\"isLatestDocument\":true}";

        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.status").value("UNDER_REVIEW"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.decision").value("REVISIÓN"));

        User unchanged = userRepository.findById(user.getId()).get();
        // El usuario NO debe ser promovido a LOCALLY_VERIFIED
        assertEquals(UserStatus.PENDING_VERIFICATION, unchanged.getStatus());

        // CU-0030: Registro de Auditoría en Blockchain para REVISIÓN
        assertEquals(1, auditLogRepository.count());
        assertEquals("REVISIÓN", auditLogRepository.findAll().get(0).getDecision());
    }

    @Test
    public void informLocalResult_RiskBlocked_Returns403WithRiskBlocked() throws Exception {
        User user = new User();
        user.setEmail("block@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // Puntuaciones bajas generan score >= 80 (BLOQUEAR)
        String requestBody = "{\"dniHash\":\"block-hash\",\"livenessScore\":10,\"faceMatchScore\":10,\"isLatestDocument\":false}";

        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isForbidden())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.errorCode").value("RISK_BLOCKED"))
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.decision").value("BLOQUEAR"));

        User unchanged = userRepository.findById(user.getId()).get();
        assertEquals(UserStatus.REGISTERED, unchanged.getStatus());

        // CU-0030: Registro de Auditoría en Blockchain para BLOQUEAR
        assertEquals(1, auditLogRepository.count());
        assertEquals("BLOQUEAR", auditLogRepository.findAll().get(0).getDecision());
    }

    @Test
    public void informLocalResult_EmulatorDetected_Returns403Forbidden() throws Exception {
        User user = new User();
        user.setEmail("emu@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        String requestBody = "{\"dniHash\":\"some-hash\",\"emulatorDetected\":true}";

        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isForbidden())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath("$.errorCode").value("EMULATOR_DETECTED"));

        // Status should NOT be updated to LOCALLY_VERIFIED
        User unchanged = userRepository.findById(user.getId()).get();
        assertEquals(UserStatus.REGISTERED, unchanged.getStatus());

        // CU-0030: Registro de Auditoría en Blockchain para regla dura de emulador (BLOQUEAR)
        assertEquals(1, auditLogRepository.count());
        assertEquals("BLOQUEAR", auditLogRepository.findAll().get(0).getDecision());
    }

    @Test
    public void informLocalResult_MultipleAttemptsBySameUser_GeneratesDistinctSessionHashAndAuditLogs() throws Exception {
        User user = new User();
        user.setEmail("multi-attempt@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // Intento 1: falla con score alto (BLOQUEAR) y attemptId explícito
        String reqAttempt1 = "{\"dniHash\":\"hash-1\",\"attemptId\":\"attempt-001\",\"livenessScore\":10,\"faceMatchScore\":10,\"isLatestDocument\":false}";
        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(reqAttempt1))
                .andExpect(status().isForbidden());

        assertEquals(1, auditLogRepository.count());

        // Reintento idéntico del Intento 1 (retransmisión de red con mismo attemptId):
        // la regla de idempotencia debe evitar duplicar el registro en base
        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(reqAttempt1))
                .andExpect(status().isForbidden());

        assertEquals(1, auditLogRepository.count(), "Mismo attemptId debe retornar el registro existente sin duplicar");

        // Intento 2 legítimo posterior del MISMO usuario con attemptId distinto (también BLOQUEAR)
        String reqAttempt2 = "{\"dniHash\":\"hash-2\",\"attemptId\":\"attempt-002\",\"livenessScore\":15,\"faceMatchScore\":15,\"isLatestDocument\":false}";
        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(reqAttempt2))
                .andExpect(status().isForbidden());

        // El nuevo intento genera un sessionHash distinto y NO colisiona en uq_blockchain_session_decision
        var logs = auditLogRepository.findAll();
        assertNotEquals(logs.get(0).getSessionHash(), logs.get(1).getSessionHash(),
                "Los sessionHash deben ser distintos entre intentos para el mismo usuario");
    }

    @Test
    public void informLocalResult_RecordsMaskedIpAndDniHash_OnSuccessAndFailure() throws Exception {
        User user = new User();
        user.setEmail("cu0029@example.com");
        user.setPasswordHash("hash");
        user.setStatus(UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // Caso Éxito (AUTORIZAR) con IP de cliente
        String reqSuccess = "{\"dniHash\":\"dni-hash-success\",\"livenessScore\":99,\"faceMatchScore\":99,\"isLatestDocument\":true}";
        mockMvc.perform(post("/verification/local-result")
                .with(request -> {
                    request.setRemoteAddr("190.24.123.45");
                    return request;
                })
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(reqSuccess))
                .andExpect(status().isOk());

        assertEquals(1, auditLogRepository.count());
        BlockchainAuditLog successLog = auditLogRepository.findAll().get(0);
        assertEquals("AUTORIZAR", successLog.getDecision());
        assertEquals("190.24.***.***", successLog.getMaskedIp());
        assertEquals("dni-hash-success", successLog.getDniHash());
        assertNotNull(successLog.getDniSearchHash());

        // Caso Fracaso (BLOQUEAR)
        String reqFailure = "{\"dniHash\":\"dni-hash-failure\",\"attemptId\":\"attempt-fail-99\",\"livenessScore\":5,\"faceMatchScore\":5,\"isLatestDocument\":false}";
        mockMvc.perform(post("/verification/local-result")
                .with(request -> {
                    request.setRemoteAddr("200.45.67.89");
                    return request;
                })
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(reqFailure))
                .andExpect(status().isForbidden());

        assertEquals(2, auditLogRepository.count());
        BlockchainAuditLog failureLog = auditLogRepository.findAll().get(1);
        assertEquals("BLOQUEAR", failureLog.getDecision());
        assertEquals("200.45.***.***", failureLog.getMaskedIp());
        assertEquals("dni-hash-failure", failureLog.getDniHash());
        assertNotNull(failureLog.getDniSearchHash());
    }
}
