package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.ReauthRequest;
import com.authenticator.dto.ReauthResponse;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class ReauthExportSecurityTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepo;

    @Autowired
    private com.authenticator.repository.RefreshTokenRepository refreshTokenRepo;

    @Autowired
    private com.authenticator.repository.AuthAuditLogRepository authAuditRepo;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private final PasswordEncoder passwordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    private User testUser;
    private final String password = "Password10Chars!";
    private String userBearerToken;

    @BeforeEach
    public void setUp() {
        authAuditRepo.deleteAll();
        refreshTokenRepo.deleteAll();
        userRepo.deleteAll();

        testUser = new User();
        testUser.setEmail("reauth_test@sip.gob.ar");
        testUser.setPasswordHash(passwordEncoder.encode(password));
        testUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        testUser = userRepo.save(testUser);

        userBearerToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
    }

    @Test
    public void reauth_WithValidPassword_ReturnsSingleUseToken() throws Exception {
        ReauthRequest req = new ReauthRequest(password);

        MvcResult result = mockMvc.perform(post("/auth/reauth")
                .header("Authorization", "Bearer " + userBearerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.reauthToken").isString())
                .andExpect(jsonPath("$.expiresInSeconds").isNumber())
                .andReturn();

        ReauthResponse resp = objectMapper.readValue(result.getResponse().getContentAsString(), ReauthResponse.class);
        assertNotNull(resp.getReauthToken());
        assertTrue(resp.getExpiresInSeconds() > 0);
    }

    @Test
    public void reauth_WithInvalidPassword_Returns401() throws Exception {
        ReauthRequest req = new ReauthRequest("WrongPass!");

        mockMvc.perform(post("/auth/reauth")
                .header("Authorization", "Bearer " + userBearerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void exportActivity_WithoutReauthToken_Returns403() throws Exception {
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken))
                .andExpect(status().isForbidden());
    }

    @Test
    public void exportActivity_WithValidReauthToken_SucceedsOnce_AndSecondAttemptFails() throws Exception {
        // 1. Obtener reauth token
        ReauthRequest req = new ReauthRequest(password);
        MvcResult reauthResult = mockMvc.perform(post("/auth/reauth")
                .header("Authorization", "Bearer " + userBearerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();

        ReauthResponse reauthResp = objectMapper.readValue(reauthResult.getResponse().getContentAsString(), ReauthResponse.class);
        String reauthToken = reauthResp.getReauthToken();

        // 2. Primer uso en exportación -> 200 OK
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.signature").isString())
                .andExpect(jsonPath("$.integrityHashSha256").isString());

        // 3. Reutilización del mismo reauth token -> 403 Forbidden (Strict Single Use)
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userBearerToken)
                .header("X-Reauth-Token", reauthToken))
                .andExpect(status().isForbidden());
    }

    @Test
    public void reauthToken_CannotBeUsedAsBearerAccessToken() throws Exception {
        // Obtener reauth token
        ReauthRequest req = new ReauthRequest(password);
        MvcResult reauthResult = mockMvc.perform(post("/auth/reauth")
                .header("Authorization", "Bearer " + userBearerToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();

        ReauthResponse reauthResp = objectMapper.readValue(reauthResult.getResponse().getContentAsString(), ReauthResponse.class);
        String reauthToken = reauthResp.getReauthToken();

        // Intentar usarlo como Bearer en /users/me -> debe ser rechazado con 401
        mockMvc.perform(get("/users/me")
                .header("Authorization", "Bearer " + reauthToken))
                .andExpect(status().isUnauthorized());
    }
}
