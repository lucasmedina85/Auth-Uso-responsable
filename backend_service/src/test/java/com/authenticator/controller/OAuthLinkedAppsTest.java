package com.authenticator.controller;

import com.authenticator.domain.*;
import com.authenticator.dto.UnlinkAppRequest;
import com.authenticator.repository.LinkedApplicationRepository;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.OAuthClientRepository;
import com.authenticator.repository.OAuthIssuedTokenRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.authenticator.security.RevocationStore;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class OAuthLinkedAppsTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private OAuthClientRepository clientRepository;

    @Autowired
    private LinkedApplicationRepository linkedAppRepository;

    @Autowired
    private OAuthIssuedTokenRepository tokenRepository;

    @Autowired
    private OAuthAuditLogRepository auditLogRepository;

    @Autowired
    private RevocationStore revocationStore;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private com.authenticator.service.ReauthService reauthService;

    @Autowired
    private ObjectMapper objectMapper;

    @Value("${app.oauth.audit-secret:${app.oauth.pairwise-secret:${OAUTH_AUDIT_SECRET:dev-audit-secret}}}")
    private String auditSecret;

    private User testUser;
    private String userToken;
    private OAuthClient testClient;

    @BeforeEach
    void setUp() {
        auditLogRepository.deleteAll();
        tokenRepository.deleteAll();
        linkedAppRepository.deleteAll();
        clientRepository.deleteById("casino-online");
        userRepository.findByEmail("linkedapps@example.com").ifPresent(userRepository::delete);

        testUser = new User();
        testUser.setEmail("linkedapps@example.com");
        testUser.setPasswordHash("hashed_pwd");
        testUser.setDniHash("dni-hash-linked-apps-test");
        testUser.setStatus(UserStatus.VERIFIED);
        testUser = userRepository.save(testUser);

        userToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");

        testClient = new OAuthClient();
        testClient.setClientId("casino-online");
        testClient.setName("Casino Online S.A.");
        testClient.setClientSecretHash("secret_hash");
        testClient.setStatus("ACTIVE");
        testClient.setAllowedScopes("openid profile age_verification");
        testClient.getRedirectUris().add("https://casino.example.com/callback");
        testClient = clientRepository.save(testClient);
    }

    @Test
    void getLinkedApplications_WithoutAuth_Returns401() throws Exception {
        mockMvc.perform(get("/oauth/linked-applications"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void getLinkedApplications_WithAuth_ReturnsEmptyWhenNoTokens() throws Exception {
        mockMvc.perform(get("/oauth/linked-applications")
                .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(0));
    }

    @Test
    void getLinkedApplications_WithTokens_ReturnsLinkedAppsList() throws Exception {
        LinkedApplication linkedApp = new LinkedApplication();
        linkedApp.setUserId(testUser.getId());
        linkedApp.setClientId(testClient.getClientId());
        linkedApp.setLinkedAt(LocalDateTime.now().minusDays(2));
        linkedApp.setLastUsedAt(LocalDateTime.now().minusMinutes(5));
        linkedApp.setStatus("ACTIVE");
        linkedApp.setScopes("openid profile age_verification");
        linkedAppRepository.save(linkedApp);

        OAuthIssuedToken token = new OAuthIssuedToken();
        token.setUserId(testUser.getId());
        token.setClientId(testClient.getClientId());
        token.setJti(UUID.randomUUID().toString());
        token.setTokenIdHash("hash-" + UUID.randomUUID());
        token.setCodeHash("code-" + UUID.randomUUID());
        token.setExpiresAt(LocalDateTime.now().plusHours(1));
        token.setStatus("ACTIVE");
        tokenRepository.save(token);

        mockMvc.perform(get("/oauth/linked-applications")
                .header("Authorization", "Bearer " + userToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isArray())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].clientId").value("casino-online"))
                .andExpect(jsonPath("$[0].appName").value("Casino Online S.A."))
                .andExpect(jsonPath("$[0].tokenStatus").value("VIGENTE"))
                .andExpect(jsonPath("$[0].scopes").value("openid profile age_verification"));
    }

    @Test
    void unlinkApplication_RevokesTokensAndReturnsSuccess() throws Exception {
        LinkedApplication linkedApp = new LinkedApplication();
        linkedApp.setUserId(testUser.getId());
        linkedApp.setClientId(testClient.getClientId());
        linkedApp.setLinkedAt(LocalDateTime.now().minusDays(2));
        linkedApp.setLastUsedAt(LocalDateTime.now().minusMinutes(5));
        linkedApp.setStatus("ACTIVE");
        linkedApp.setScopes("openid");
        linkedAppRepository.save(linkedApp);

        String testJti = "jti-unlink-" + UUID.randomUUID();
        OAuthIssuedToken token = new OAuthIssuedToken();
        token.setUserId(testUser.getId());
        token.setClientId(testClient.getClientId());
        token.setJti(testJti);
        token.setTokenIdHash("hash-" + UUID.randomUUID());
        token.setCodeHash("code-" + UUID.randomUUID());
        token.setExpiresAt(LocalDateTime.now().plusHours(1));
        token.setStatus("ACTIVE");
        tokenRepository.save(token);

        UnlinkAppRequest request = new UnlinkAppRequest();
        request.setClientId("casino-online");

        mockMvc.perform(post("/oauth/unlink")
                .header("Authorization", "Bearer " + userToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.unlinked").value(true));

        // Verificar que en base de datos quedó revocado
        OAuthIssuedToken updatedToken = tokenRepository.findByUserIdAndClientIdOrderByCreatedAtDesc(testUser.getId(), "casino-online")
                .get(0);
        assertEquals("REVOKED", updatedToken.getStatus());
        assertNotNull(updatedToken.getRevokedAt());

        // Verificar que el JTI fue revocado en RevocationStore
        assertTrue(revocationStore.isRevoked(testJti));
    }

    @Test
    void exportLinkedApplicationsLog_GeneratesCertifiedSignedExport() throws Exception {
        String userHash = hmacSha256(testUser.getId().toString(), auditSecret);

        OAuthAuditLog audit = new OAuthAuditLog();
        audit.setEventType("AUTHORIZATION_CODE_ISSUED");
        audit.setClientId(testClient.getClientId());
        audit.setUserIdHash(userHash);
        audit.setDetails("Autorización emitida");
        auditLogRepository.save(audit);

        String reauthToken = reauthService.generateReauthToken(testUser.getId(), "EXPORT");
        MvcResult result = mockMvc.perform(get("/oauth/linked-applications/export")
                .header("Authorization", "Bearer " + userToken)
                .header("X-Reauth-Token", reauthToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.integrityHashSha256").isString())
                .andExpect(jsonPath("$.signature").isString())
                .andExpect(jsonPath("$.signingAlgorithm").value("SHA256withRSA"))
                .andExpect(jsonPath("$.exportFormat").value("JSON"))
                .andExpect(jsonPath("$.payload.schemaVersion").value("1.0.0"))
                .andReturn();

        JsonNode root = objectMapper.readTree(result.getResponse().getContentAsString());
        assertNotNull(root.get("payload"));
        assertEquals(1, root.get("payload").get("totalRecords").asInt());
    }

    private String hmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] hash = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
}
