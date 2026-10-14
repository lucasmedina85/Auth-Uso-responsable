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

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
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
    private com.authenticator.service.AuthService authService;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    public void setup() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();
        authService.resetNonExistentLoginTrackers();
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

    @Test
    public void login_AntiEnumeration_IdenticalResponseSequenceForExistingAndNonExistingUsers() throws Exception {
        // Registrar usuario existente
        RegisterRequest regReq = new RegisterRequest();
        regReq.setEmail("realuser@example.com");
        regReq.setPassword("ValidPassword123!");
        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(regReq)))
                .andExpect(status().isCreated());

        List<Integer> existingStatusCodes = new ArrayList<>();
        List<String> existingResponses = new ArrayList<>();

        // 6 intentos fallidos con usuario existente (IPs distintas para aislar el bloqueo de cuenta del rate limiter por IP)
        for (int i = 1; i <= 6; i++) {
            final int ipSuffix = i;
            LoginRequest req = new LoginRequest();
            req.setEmail("realuser@example.com");
            req.setPassword("wrong-pass-" + i);

            var result = mockMvc.perform(post("/auth/login")
                    .with(request -> {
                        request.setRemoteAddr("192.168.10." + ipSuffix);
                        return request;
                    })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(req)))
                    .andReturn();

            existingStatusCodes.add(result.getResponse().getStatus());
            existingResponses.add(result.getResponse().getContentAsString());
        }

        List<Integer> nonExistentStatusCodes = new ArrayList<>();
        List<String> nonExistentResponses = new ArrayList<>();

        // 6 intentos fallidos con usuario inexistente (mismo esquema)
        for (int i = 1; i <= 6; i++) {
            final int ipSuffix = i;
            LoginRequest req = new LoginRequest();
            req.setEmail("ghostuser@example.com");
            req.setPassword("wrong-pass-" + i);

            var result = mockMvc.perform(post("/auth/login")
                    .with(request -> {
                        request.setRemoteAddr("192.168.20." + ipSuffix);
                        return request;
                    })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(req)))
                    .andReturn();

            nonExistentStatusCodes.add(result.getResponse().getStatus());
            nonExistentResponses.add(result.getResponse().getContentAsString());
        }

        // Verificar que la secuencia de códigos y mensajes es rigurosamente idéntica: 5x 401 y luego 429
        assertEquals(List.of(401, 401, 401, 401, 401, 429), existingStatusCodes);
        assertEquals(existingStatusCodes, nonExistentStatusCodes);
        assertEquals(existingResponses, nonExistentResponses);
        assertEquals("Demasiados intentos, probá más tarde", existingResponses.get(5));
    }

    @Test
    public void login_IpRateLimiting_UsesIpResolver_BlocksAfterFiveRequestsFromSameIp() throws Exception {
        String testIp = "192.168.50.100";
        for (int i = 1; i <= 5; i++) {
            LoginRequest req = new LoginRequest();
            req.setEmail("random" + i + "@example.com");
            req.setPassword("anypass");

            mockMvc.perform(post("/auth/login")
                    .with(request -> {
                        request.setRemoteAddr(testIp);
                        return request;
                    })
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(objectMapper.writeValueAsString(req)))
                    .andExpect(status().isUnauthorized());
        }

        // El 6to intento desde la misma IP debe ser 429 (bloqueado por IP)
        LoginRequest req = new LoginRequest();
        req.setEmail("another@example.com");
        req.setPassword("anypass");

        mockMvc.perform(post("/auth/login")
                .with(request -> {
                    request.setRemoteAddr(testIp);
                    return request;
                })
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isTooManyRequests())
                .andExpect(org.springframework.test.web.servlet.result.MockMvcResultMatchers.content().string("Demasiados intentos, probá más tarde"));
    }
}
