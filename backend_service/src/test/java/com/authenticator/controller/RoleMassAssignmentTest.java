package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.util.HashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class RoleMassAssignmentTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private com.authenticator.repository.RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private static final String TEST_EMAIL = "attacker_admin@sip.gob.ar";

    @AfterEach
    public void cleanup() {
        refreshTokenRepository.deleteAll();
        userRepository.findByEmail(TEST_EMAIL).ifPresent(userRepository::delete);
    }

    @Test
    public void register_WithAdminRoleInPayload_IgnoresRoleAndEnforcesUserRole() throws Exception {
        Map<String, Object> maliciousPayload = new HashMap<>();
        maliciousPayload.put("email", TEST_EMAIL);
        maliciousPayload.put("password", "SecurePassword123!");
        maliciousPayload.put("role", "ADMIN"); // Intento de escalamiento de privilegios por Mass Assignment

        mockMvc.perform(post("/auth/register")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(maliciousPayload)))
                .andExpect(status().isCreated());

        User user = userRepository.findByEmail(TEST_EMAIL).orElseThrow();
        assertEquals("USER", user.getRole(), "El rol debe ser forzado a USER y nunca tomar el valor enviado por el cliente");

        // Intentar loguear y verificar que el token emitido no tenga privilegios ADMIN
        Map<String, String> loginPayload = Map.of(
                "email", TEST_EMAIL,
                "password", "SecurePassword123!"
        );

        MvcResult loginResult = mockMvc.perform(post("/auth/login")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(loginPayload)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginJson = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String accessToken = loginJson.get("accessToken").asText();

        // Con este token, no debe poder acceder a endpoints de administración
        mockMvc.perform(get("/admin/blockchain/status")
                .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isForbidden());
    }
}
