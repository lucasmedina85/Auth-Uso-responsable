package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.LoginRequest;
import com.authenticator.dto.RegisterRequest;
import com.authenticator.repository.RefreshTokenRepository;
import com.authenticator.repository.UserRepository;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import com.authenticator.security.JwtUtil;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
public class AuthControllerTest {

    @Test
    public void logout_AddsJtiToDenylist() throws Exception {
        User user = new User();
        user.setEmail("logout@example.com");
        user.setPasswordHash("hash");
        user.setStatus(com.authenticator.domain.UserStatus.REGISTERED);
        user = userRepository.save(user);

        String token = jwtUtil.generateAccessToken(user.getId().toString());

        // Call logout
        mockMvc.perform(post("/auth/logout")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk());

        // Second call to protected endpoint should fail (401)
        mockMvc.perform(MockMvcRequestBuilders.get("/users/me")
                .header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized());
    }

    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    public void setup() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    public void register_ValidRequest_Success() throws Exception {
        RegisterRequest req = new RegisterRequest();
        req.setEmail("test@example.com");
        req.setPassword("ValidPassword123!");

        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());

        assertTrue(userRepository.findByEmail("test@example.com").isPresent());
    }

    @Test
    public void login_InvalidPassword_Returns401() throws Exception {
        RegisterRequest req = new RegisterRequest();
        req.setEmail("test@example.com");
        req.setPassword("ValidPassword123!");

        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());

        LoginRequest loginReq = new LoginRequest();
        loginReq.setEmail("test@example.com");
        loginReq.setPassword("inventada123");

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isUnauthorized());
    }

    @Test
    public void login_ValidPassword_Returns200() throws Exception {
        RegisterRequest req = new RegisterRequest();
        req.setEmail("test@example.com");
        req.setPassword("ValidPassword123!");

        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated());

        LoginRequest loginReq = new LoginRequest();
        loginReq.setEmail("test@example.com");
        loginReq.setPassword("ValidPassword123!");

        mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk());
    }
}
