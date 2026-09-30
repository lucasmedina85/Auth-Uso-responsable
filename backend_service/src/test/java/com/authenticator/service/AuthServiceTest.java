package com.authenticator.service;

import com.authenticator.domain.RefreshToken;
import com.authenticator.domain.User;
import com.authenticator.dto.AuthResponse;
import com.authenticator.dto.LoginRequest;
import com.authenticator.dto.RefreshRequest;
import com.authenticator.dto.RegisterRequest;
import com.authenticator.repository.RefreshTokenRepository;
import com.authenticator.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("dev")
@Transactional
public class AuthServiceTest {

    @Test
    public void testLoginTimingAttackMitigationWhenUserNotFound() {
        LoginRequest request = new LoginRequest();
        request.setEmail("unknown@example.com");
        request.setPassword("password123");

        long startTime = System.currentTimeMillis();
        assertThrows(SecurityException.class, () -> authService.login(request));
        long duration = System.currentTimeMillis() - startTime;
        
        // El proceso debería tomar cierto tiempo de hashing, no ser instantáneo (< 10ms).
        assertTrue(duration > 10, "Login fallido para usuario inexistente debería demorar debido al hashing mitigando timing attacks");
    }

    @Autowired
    private AuthService authService;

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
    public void testRefreshRotationAndReuseDetection() {
        // Register user
        RegisterRequest req = new RegisterRequest();
        req.setEmail("reuse@example.com");
        req.setPassword("Password123!");
        authService.register(req);

        // Login to get token
        LoginRequest loginReq = new LoginRequest();
        loginReq.setEmail("reuse@example.com");
        loginReq.setPassword("Password123!");
        AuthResponse loginResponse = authService.login(loginReq);

        String firstRefreshToken = loginResponse.getRefreshToken();
        assertNotNull(firstRefreshToken);

        // 1st Refresh: should succeed
        RefreshRequest refreshReq = new RefreshRequest();
        refreshReq.setRefreshToken(firstRefreshToken);
        AuthResponse refreshResponse = authService.refresh(refreshReq);

        assertNotNull(refreshResponse.getAccessToken());
        assertNotNull(refreshResponse.getRefreshToken());
        assertNotEquals(firstRefreshToken, refreshResponse.getRefreshToken());

        // Attempt to use the FIRST refresh token AGAIN
        assertThrows(SecurityException.class, () -> authService.refresh(refreshReq));

        // After reusing, ALL tokens for this user should be deleted (Family Revocation)
        User user = userRepository.findByEmail("reuse@example.com").get();
        List<RefreshToken> remainingTokens = refreshTokenRepository.findAll();
        assertEquals(0, remainingTokens.stream().filter(t -> t.getUser().getId().equals(user.getId())).count());
    }

    @Test
    public void testFailedLoginLockout() {
        RegisterRequest req = new RegisterRequest();
        req.setEmail("lockout@example.com");
        req.setPassword("Password123!");
        authService.register(req);

        LoginRequest loginReq = new LoginRequest();
        loginReq.setEmail("lockout@example.com");
        loginReq.setPassword("wrongpass");

        for (int i = 0; i < 5; i++) {
            assertThrows(SecurityException.class, () -> authService.login(loginReq));
        }

        // 6th attempt with CORRECT password should fail because account is locked
        loginReq.setPassword("Password123!");
        SecurityException ex = assertThrows(SecurityException.class, () -> authService.login(loginReq));
        assertTrue(ex.getMessage().contains("bloqueada"));
    }
}
