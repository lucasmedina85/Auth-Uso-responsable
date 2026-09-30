package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
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

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.junit.jupiter.api.Assertions.assertEquals;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
public class VerificationLocalControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @BeforeEach
    public void setup() {
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

        String requestBody = "{\"dniHash\":\"some-hash\"}";

        mockMvc.perform(post("/verification/local-result")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody))
                .andExpect(status().isOk());

        User updated = userRepository.findById(user.getId()).get();
        assertEquals(UserStatus.LOCALLY_VERIFIED, updated.getStatus());
        assertEquals("some-hash", updated.getDniHash());
    }
}
