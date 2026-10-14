package com.authenticator.controller;

import com.authenticator.domain.AuthAuditLog;
import com.authenticator.domain.OAuthAuditLog;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.repository.AuthAuditLogRepository;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.ExportSigningKeyManager;
import com.authenticator.security.JwtUtil;
import com.authenticator.service.ReauthService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@TestPropertySource(properties = {
        "app.export.max-range-days=90",
        "app.export.max-records=3"
})
public class ExportLimitsAndPrivacyTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private AuthAuditLogRepository authAuditRepo;

    @Autowired
    private OAuthAuditLogRepository oauthAuditRepo;

    @Autowired
    private com.authenticator.repository.RefreshTokenRepository refreshTokenRepo;

    @Autowired
    private ReauthService reauthService;

    @Autowired
    private ExportSigningKeyManager exportSigningKeyManager;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;
    private String userBearerToken;

    @BeforeEach
    void setUp() {
        authAuditRepo.deleteAll();
        oauthAuditRepo.deleteAll();
        refreshTokenRepo.deleteAll();
        userRepository.deleteAll();

        testUser = new User();
        testUser.setEmail("export_limits_test@sip.gob.ar");
        testUser.setPasswordHash("$argon2id$v=19$m=16384,t=2,p=1$dummy$dummyhash");
        testUser.setStatus(UserStatus.VERIFIED);
        testUser.setCreatedAt(LocalDateTime.now().minusDays(5));
        testUser = userRepository.save(testUser);

        userBearerToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
    }

    private String getFreshReauthToken() {
        return reauthService.generateReauthToken(testUser.getId(), "EXPORT");
    }

    // ==========================================
    // 1. Validaciones de Rango de Fechas
    // ==========================================

    @Test
    void exportActivity_WhenFromAfterTo_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().toString())
                .param("endDate", LocalDate.now().minusDays(2).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("La fecha 'from' no puede ser posterior a 'to'"));
    }

    @Test
    void exportActivity_WhenToIsFuture_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().toString())
                .param("endDate", LocalDate.now().plusDays(2).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("La fecha 'to' no puede ser futura"));
    }

    @Test
    void exportActivity_WhenRangeExceedsMaxDays_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().minusDays(100).toString())
                .param("endDate", LocalDate.now().toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error").value("El rango de fechas no puede superar los 90 días"));
    }

    @Test
    void exportLinkedApps_WhenFromAfterTo_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/oauth/linked-applications/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().toString())
                .param("endDate", LocalDate.now().minusDays(3).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error_description").value("La fecha 'from' no puede ser posterior a 'to'"));
    }

    @Test
    void exportLinkedApps_WhenToIsFuture_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/oauth/linked-applications/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().toString())
                .param("endDate", LocalDate.now().plusDays(3).toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error_description").value("La fecha 'to' no puede ser futura"));
    }

    @Test
    void exportLinkedApps_WhenRangeExceedsMaxDays_Returns400() throws Exception {
        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/oauth/linked-applications/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().minusDays(95).toString())
                .param("endDate", LocalDate.now().toString()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error_description").value("El rango de fechas no puede superar los 90 días"));
    }

    // ==========================================
    // 2. Clamping de Page y Size en Activity Query
    // ==========================================

    @Test
    void getActivity_ClampsNegativePageAndExcessiveSize() throws Exception {
        mockMvc.perform(get("/users/activity")
                .header("Authorization", "Bearer " + userBearerToken)
                .param("page", "-5")
                .param("size", "200"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(50));
    }

    // ==========================================
    // 3. Truncamiento y totalMatchingRecords (app.export.max-records = 3)
    // ==========================================

    @Test
    void exportActivity_WhenRecordsExceedMaxRecords_IncludesTruncatedAndRealCount() throws Exception {
        for (int i = 0; i < 5; i++) {
            AuthAuditLog log = new AuthAuditLog();
            log.setUser(testUser);
            log.setEmailHmac("dummy-email-hmac-" + i);
            log.setEventType("LOGIN_SUCCESS");
            log.setResult("SUCCESS");
            log.setMaskedIp("181.44.***.***");
            log.setDeviceHash("hash-" + i);
            log.setCreatedAt(LocalDateTime.now().minusHours(i + 1));
            authAuditRepo.save(log);
        }

        String reauthToken = getFreshReauthToken();
        MvcResult result = mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().minusDays(2).toString())
                .param("endDate", LocalDate.now().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.truncated").value(true))
                .andExpect(jsonPath("$.exportedRecords").value(3))
                .andExpect(jsonPath("$.keyId").value("sip-export-sig-v1"))
                .andReturn();

        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        assertTrue(json.get("totalMatchingRecords").asInt() >= 5);
        assertEquals(3, json.get("records").size());
        assertTrue(json.get("truncated").asBoolean());
    }

    @Test
    void exportActivity_WhenRecordsBelowMaxRecords_TruncatedIsFalse() throws Exception {
        AuthAuditLog log = new AuthAuditLog();
        log.setUser(testUser);
        log.setEmailHmac("dummy-email-hmac");
        log.setEventType("LOGIN_SUCCESS");
        log.setResult("SUCCESS");
        log.setMaskedIp("200.55.***.***");
        log.setCreatedAt(LocalDateTime.now().minusMinutes(30));
        authAuditRepo.save(log);

        String reauthToken = getFreshReauthToken();
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken)
                .param("startDate", LocalDate.now().minusDays(1).toString())
                .param("endDate", LocalDate.now().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.truncated").value(false))
                .andExpect(jsonPath("$.exportedRecords").value(1))
                .andExpect(jsonPath("$.totalMatchingRecords").value(1));
    }

    // ==========================================
    // 4. Privacidad Estricta: Cero Fugas de Datos
    // ==========================================

    @Test
    void exportActivityAndLinkedApps_ContainsZeroLeaksOfUnmaskedIpsTokensOrSecrets() throws Exception {
        AuthAuditLog authLog = new AuthAuditLog();
        authLog.setUser(testUser);
        authLog.setEmailHmac("dummy-email-hmac");
        authLog.setEventType("LOGIN_SUCCESS");
        authLog.setResult("SUCCESS");
        authLog.setMaskedIp("190.220.***.***");
        authLog.setDeviceHash("dev-hmac-abcdef123456");
        authLog.setCreatedAt(LocalDateTime.now().minusHours(2));
        authAuditRepo.save(authLog);

        String reauthToken = getFreshReauthToken();
        MvcResult activityResult = mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken))
                .andExpect(status().isOk())
                .andReturn();

        String activityJson = activityResult.getResponse().getContentAsString();

        // 1. No debe contener contraseñas ni hashes de contraseña
        assertFalse(activityJson.contains("passwordHash"));
        assertFalse(activityJson.contains("$argon2id$"));

        // 2. No debe contener tokens
        assertFalse(activityJson.contains("accessToken"));
        assertFalse(activityJson.contains("refreshToken"));
        assertFalse(activityJson.contains(userBearerToken));
        assertFalse(activityJson.contains(reauthToken));

        // 3. No debe contener secretSeed ni DNI en texto plano
        assertFalse(activityJson.contains("secretSeed"));
        assertFalse(activityJson.contains("rawDni"));

        // 4. No debe contener direcciones IPv4 completas sin enmascarar (todas deben tener asteriscos ***)
        Pattern unmaskedIpv4Pattern = Pattern.compile("\\b(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\b");
        Matcher matcher = unmaskedIpv4Pattern.matcher(activityJson);
        assertFalse(matcher.find(), "El export de actividad no debe contener IPs sin enmascarar");

        // 5. Debe contener la clave dedicada de firma y su firma digital RSA
        JsonNode actNode = objectMapper.readTree(activityJson);
        assertEquals("sip-export-sig-v1", actNode.get("keyId").asText());
        assertEquals("SHA256withRSA", actNode.get("signingAlgorithm").asText());
        assertTrue(actNode.hasNonNull("signature"));
        assertTrue(actNode.hasNonNull("integrityHashSha256"));

        // Export de Linked Apps
        String reauthToken2 = getFreshReauthToken();
        MvcResult linkedAppsResult = mockMvc.perform(get("/oauth/linked-applications/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken2))
                .andExpect(status().isOk())
                .andReturn();

        String linkedAppsJson = linkedAppsResult.getResponse().getContentAsString();
        assertFalse(linkedAppsJson.contains("secretSeed"));
        assertFalse(linkedAppsJson.contains("clientSecret"));
        assertFalse(linkedAppsJson.contains("accessToken"));
        assertFalse(linkedAppsJson.contains("refreshToken"));

        JsonNode linkedNode = objectMapper.readTree(linkedAppsJson);
        assertEquals("sip-export-sig-v1", linkedNode.get("keyId").asText());
        assertEquals("SHA256withRSA", linkedNode.get("signingAlgorithm").asText());
        assertTrue(linkedNode.hasNonNull("signature"));
    }
}
