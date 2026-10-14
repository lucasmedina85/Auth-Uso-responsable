package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class UserControllerTest {

    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private com.authenticator.repository.AuthAuditLogRepository authAuditRepo;

    @Autowired
    private com.authenticator.repository.RefreshTokenRepository refreshTokenRepo;

    @Autowired
    private com.authenticator.service.ReauthService reauthService;

    private User testUser;
    private String userToken;

    @BeforeEach
    void setUp() {
        authAuditRepo.deleteAll();
        refreshTokenRepo.deleteAll();
        userRepository.deleteAll();
        testUser = new User();
        testUser.setEmail("activity_test@example.com");
        testUser.setPasswordHash("hashed_pwd");
        testUser.setDniHash("dni-hash-user-1122");
        testUser.setStatus(UserStatus.VERIFIED);
        testUser = userRepository.save(testUser);
        userToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
    }

    @Test
    public void getMe_NoToken_Returns401() throws Exception {
        mockMvc.perform(get("/users/me"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void getActivity_NoToken_Returns401() throws Exception {
        mockMvc.perform(get("/users/activity"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void getActivity_WithToken_Returns200AndPage() throws Exception {
        mockMvc.perform(get("/users/activity")
                .header("Authorization", "Bearer " + userToken)
                .param("page", "0")
                .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.events").isArray())
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(10));
    }

    @Test
    public void exportActivity_WithToken_Returns200AndSignedExport() throws Exception {
        String reauthToken = reauthService.generateReauthToken(testUser.getId(), "EXPORT");
        mockMvc.perform(get("/users/activity/export")
                .header("Authorization", "Bearer " + userToken)
                .header("X-Reauth-Token", reauthToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.integrityHashSha256").isString())
                .andExpect(jsonPath("$.signature").isString())
                .andExpect(jsonPath("$.signingAlgorithm").value("SHA256withRSA"))
                .andExpect(jsonPath("$.payload.userPseudonym").isString());
    }
}
