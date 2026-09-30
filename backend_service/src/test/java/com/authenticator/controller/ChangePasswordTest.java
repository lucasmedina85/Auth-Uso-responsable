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
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertFalse;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("dev")
public class ChangePasswordTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private JwtUtil jwtUtil;
    
    @Autowired
    private PasswordEncoder passwordEncoder;

    private User testUser;
    private String token;

    @BeforeEach
    public void setup() {
        refreshTokenRepository.deleteAll();
        userRepository.deleteAll();

        testUser = new User();
        testUser.setEmail("changepw@example.com");
        testUser.setPasswordHash(passwordEncoder.encode("oldPassword123"));
        testUser.setStatus(UserStatus.REGISTERED);
        testUser = userRepository.save(testUser);

        token = jwtUtil.generateAccessToken(testUser.getId().toString());
    }

    @Test
    public void changePassword_Success_ReturnsNewTokens() throws Exception {
        String req = "{\"currentPassword\":\"oldPassword123\",\"newPassword\":\"newPassword12345\"}";
        mockMvc.perform(post("/auth/change-password")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(req))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists());
                
        User updated = userRepository.findById(testUser.getId()).get();
        assertTrue(passwordEncoder.matches("newPassword12345", updated.getPasswordHash()));
        assertFalse(passwordEncoder.matches("oldPassword123", updated.getPasswordHash()));
    }

    @Test
    public void changePassword_WrongCurrentPassword_Returns403() throws Exception {
        String req = "{\"currentPassword\":\"wrongPassword\",\"newPassword\":\"newPassword12345\"}";
        mockMvc.perform(post("/auth/change-password")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(req))
                .andExpect(status().isForbidden());
    }

    @Test
    public void changePassword_WeakPassword_Returns400() throws Exception {
        String req = "{\"currentPassword\":\"oldPassword123\",\"newPassword\":\"short\"}";
        mockMvc.perform(post("/auth/change-password")
                .header("Authorization", "Bearer " + token)
                .contentType(MediaType.APPLICATION_JSON)
                .content(req))
                .andExpect(status().isBadRequest());
    }
}
