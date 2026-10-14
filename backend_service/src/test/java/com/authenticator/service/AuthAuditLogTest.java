package com.authenticator.service;

import com.authenticator.domain.AuthAuditLog;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.LoginRequest;
import com.authenticator.repository.AuthAuditLogRepository;
import com.authenticator.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
public class AuthAuditLogTest {

    @Autowired
    private AuthService authService;

    @Autowired
    private AuthAuditService authAuditService;

    @Autowired
    private AuthAuditLogRepository auditRepo;

    @Autowired
    private UserRepository userRepo;

    @Autowired
    private com.authenticator.repository.RefreshTokenRepository refreshTokenRepo;

    @Autowired
    private com.authenticator.security.JwtUtil jwtUtil;

    private final PasswordEncoder passwordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();
    private User testUser;
    private final String password = "Password10Chars!";

    @BeforeEach
    public void setUp() {
        auditRepo.deleteAll();
        refreshTokenRepo.deleteAll();
        userRepo.deleteAll();

        testUser = new User();
        testUser.setEmail("audit_test@sip.gob.ar");
        testUser.setPasswordHash(passwordEncoder.encode(password));
        testUser.setStatus(UserStatus.REGISTERED);
        testUser = userRepo.save(testUser);
    }

    private LoginRequest createLoginRequest(String email, String password) {
        LoginRequest req = new LoginRequest();
        req.setEmail(email);
        req.setPassword(password);
        return req;
    }

    @Test
    public void loginSuccess_RecordsAuthAuditLogWithMaskedIpAndDeviceHash() {
        LoginRequest req = createLoginRequest("audit_test@sip.gob.ar", password);
        var resp = authService.login(req, "192.168.1.150", "device-abc-123");
        assertNotNull(resp);

        List<AuthAuditLog> logs = auditRepo.findByUserIdOrderByCreatedAtDesc(testUser.getId());
        assertEquals(1, logs.size());
        AuthAuditLog log = logs.get(0);
        assertEquals("LOGIN_SUCCESS", log.getEventType());
        assertEquals("SUCCESS", log.getResult());
        assertEquals("192.168.***.***", log.getMaskedIp());
        assertNotNull(log.getDeviceHash());
        assertNotNull(log.getCreatedAt());
    }

    @Test
    public void loginFailed_ExistingUser_RecordsFailureLinkedToUser() {
        LoginRequest req = createLoginRequest("audit_test@sip.gob.ar", "WrongPassword!");
        try {
            authService.login(req, "10.0.0.5", "device-abc-123");
        } catch (Exception ignored) {}

        List<AuthAuditLog> logs = auditRepo.findByUserIdOrderByCreatedAtDesc(testUser.getId());
        assertEquals(1, logs.size());
        AuthAuditLog log = logs.get(0);
        assertEquals("LOGIN_FAILED", log.getEventType());
        assertEquals("FAILURE", log.getResult());
        assertNotNull(log.getUser());
        assertEquals(testUser.getId(), log.getUser().getId());
        assertEquals("10.0.***.***", log.getMaskedIp());
    }

    @Test
    public void loginFailed_NonExistentUser_RecordsHmacOnlyAndNeverLinksToAnyUser() {
        LoginRequest req = createLoginRequest("nonexistent@sip.gob.ar", "WrongPassword!");
        try {
            authService.login(req, "172.16.50.2", "device-abc-123");
        } catch (Exception ignored) {}

        // No debe aparecer en la actividad del usuario existente
        List<AuthAuditLog> userLogs = auditRepo.findByUserIdOrderByCreatedAtDesc(testUser.getId());
        assertTrue(userLogs.isEmpty());

        // Debe haberse guardado con user_id null y solo email_hmac
        List<AuthAuditLog> allLogs = auditRepo.findAll();
        assertEquals(1, allLogs.size());
        AuthAuditLog nonExistentLog = allLogs.get(0);
        assertNull(nonExistentLog.getUser());
        assertNotNull(nonExistentLog.getEmailHmac());
        assertEquals("LOGIN_FAILED", nonExistentLog.getEventType());
        assertEquals("FAILURE", nonExistentLog.getResult());
    }

    @Test
    public void logout_RecordsLogoutEvent() {
        String token = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
        authService.logout(token, null, "192.168.1.150", "device-abc-123");

        List<AuthAuditLog> logs = auditRepo.findByUserIdOrderByCreatedAtDesc(testUser.getId());
        assertEquals(1, logs.size());
        AuthAuditLog log = logs.get(0);
        assertEquals("LOGOUT", log.getEventType());
        assertEquals("SUCCESS", log.getResult());
    }

    @Test
    public void purgeOldLogs_DeletesLogsOlderThanCutoff() {
        AuthAuditLog oldLog = new AuthAuditLog();
        oldLog.setUser(testUser);
        oldLog.setEmailHmac("dummy-email-hmac");
        oldLog.setEventType("LOGIN_SUCCESS");
        oldLog.setResult("SUCCESS");
        oldLog.setMaskedIp("127.0.***.***");
        oldLog.setCreatedAt(LocalDateTime.now().minusDays(100));
        auditRepo.save(oldLog);

        int deleted = auditRepo.deleteOlderThan(LocalDateTime.now().minusDays(90));
        assertTrue(deleted >= 1);
    }
}
