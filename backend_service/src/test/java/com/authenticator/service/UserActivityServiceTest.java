package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.dto.UserActivityEventDTO;
import com.authenticator.dto.UserActivityPageResponse;
import com.authenticator.repository.AuthAuditLogRepository;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.ExportSigningKeyManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.Signature;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
public class UserActivityServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private BlockchainAuditLogRepository blockchainRepo;

    @Mock
    private TrustedDeviceRepository deviceRepo;

    @Mock
    private OAuthAuditLogRepository oauthAuditRepo;

    @Mock
    private AuthAuditLogRepository authAuditRepo;

    @Mock
    private ExportSigningKeyManager exportSigningKeyManager;

    @InjectMocks
    private UserActivityService userActivityService;

    private UUID userId;
    private User testUser;
    private RSAPublicKey publicKey;
    private RSAPrivateKey privateKey;

    @BeforeEach
    void setUp() throws Exception {
        userId = UUID.randomUUID();
        testUser = new User();
        testUser.setId(userId);
        testUser.setEmail("user@example.com");
        testUser.setDniHash("dni-hash-12345");
        testUser.setStatus(UserStatus.VERIFIED);
        testUser.setCreatedAt(LocalDateTime.now().minusDays(10));
        testUser.setUpdatedAt(LocalDateTime.now().minusHours(1));

        ReflectionTestUtils.setField(userActivityService, "auditSecret", "test-audit-secret-key-12345");
        ReflectionTestUtils.setField(userActivityService, "maxRangeDays", 90);
        ReflectionTestUtils.setField(userActivityService, "maxRecords", 500);

        KeyPairGenerator kpg = KeyPairGenerator.getInstance("RSA");
        kpg.initialize(2048);
        KeyPair kp = kpg.generateKeyPair();
        publicKey = (RSAPublicKey) kp.getPublic();
        privateKey = (RSAPrivateKey) kp.getPrivate();

        lenient().when(exportSigningKeyManager.getPrimaryKeyId()).thenReturn("sip-export-sig-v1");
        lenient().when(exportSigningKeyManager.sign(anyString())).thenAnswer(inv -> {
            String data = inv.getArgument(0);
            Signature sig = Signature.getInstance("SHA256withRSA");
            sig.initSign(privateKey);
            sig.update(data.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(sig.sign());
        });
        lenient().when(authAuditRepo.findByUserIdOrderByCreatedAtDesc(any())).thenReturn(Collections.emptyList());
    }

    @Test
    void getUserActivity_AggregatesAndSortsEventsDesc() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));

        BlockchainAuditLog bcLog = new BlockchainAuditLog();
        bcLog.setDecision("AUTORIZAR");
        bcLog.setScore(15);
        bcLog.setCreatedAt(LocalDateTime.now().minusDays(1));
        bcLog.setSessionId("sess-1");
        bcLog.setMaskedIp("192.168.***.***");
        when(blockchainRepo.findByDniHashOrderByCreatedAtDesc(any())).thenReturn(List.of(bcLog));

        TrustedDevice dev = new TrustedDevice();
        dev.setDeviceName("Pixel 7");
        dev.setStatus(TrustedDeviceStatus.TRUSTED);
        dev.setCreatedAt(LocalDateTime.now().minusDays(3));
        dev.setLastSeenAt(LocalDateTime.now().minusDays(1));
        when(deviceRepo.findByUserIdOrderByCreatedAtDesc(userId)).thenReturn(List.of(dev));

        OAuthAuditLog oLog = new OAuthAuditLog();
        oLog.setEventType("AUTHORIZATION_CODE_ISSUED");
        oLog.setClientId("bet-app");
        oLog.setCreatedAt(LocalDateTime.now().minusDays(2));
        when(oauthAuditRepo.findByUserIdHashOrderByCreatedAtDesc(any())).thenReturn(List.of(oLog));

        UserActivityPageResponse response = userActivityService.getUserActivity(userId, 0, 10, null, null, null);

        assertNotNull(response);
        assertTrue(response.getTotalElements() >= 4); // User created + bcLog + dev + oLog
        // Assert descending order
        List<UserActivityEventDTO> events = response.getEvents();
        for (int i = 0; i < events.size() - 1; i++) {
            assertFalse(events.get(i).getTimestamp().isBefore(events.get(i + 1).getTimestamp()));
        }
    }

    @Test
    void getUserActivity_FilterByType_ReturnsOnlyMatchingEvents() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(blockchainRepo.findByDniHashOrderByCreatedAtDesc(any())).thenReturn(Collections.emptyList());
        when(deviceRepo.findByUserIdOrderByCreatedAtDesc(userId)).thenReturn(Collections.emptyList());

        OAuthAuditLog oLog = new OAuthAuditLog();
        oLog.setEventType("TOKEN_REVOKED");
        oLog.setClientId("bet-app");
        oLog.setCreatedAt(LocalDateTime.now().minusHours(2));
        when(oauthAuditRepo.findByUserIdHashOrderByCreatedAtDesc(any())).thenReturn(List.of(oLog));

        UserActivityPageResponse response = userActivityService.getUserActivity(userId, 0, 10, "OAUTH", null, null);

        assertNotNull(response);
        assertEquals(1, response.getTotalElements());
        assertEquals("OAUTH", response.getEvents().get(0).getType());
    }

    @Test
    void getUserActivity_Pagination_CalculatesCorrectPages() {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        List<OAuthAuditLog> logs = new ArrayList<>();
        for (int i = 0; i < 15; i++) {
            OAuthAuditLog l = new OAuthAuditLog();
            l.setEventType("CODE_ISSUED");
            l.setClientId("app-" + i);
            l.setCreatedAt(LocalDateTime.now().minusHours(i));
            logs.add(l);
        }
        when(oauthAuditRepo.findByUserIdHashOrderByCreatedAtDesc(any())).thenReturn(logs);
        when(blockchainRepo.findByDniHashOrderByCreatedAtDesc(any())).thenReturn(Collections.emptyList());
        when(deviceRepo.findByUserIdOrderByCreatedAtDesc(userId)).thenReturn(Collections.emptyList());

        UserActivityPageResponse page0 = userActivityService.getUserActivity(userId, 0, 5, "OAUTH", null, null);
        assertEquals(15, page0.getTotalElements());
        assertEquals(5, page0.getEvents().size());
        assertEquals(3, page0.getTotalPages());
        assertTrue(page0.isHasNext());

        UserActivityPageResponse page2 = userActivityService.getUserActivity(userId, 2, 5, "OAUTH", null, null);
        assertEquals(5, page2.getEvents().size());
        assertFalse(page2.isHasNext());
    }

    @Test
    void exportUserActivity_GeneratesValidSha256AndRsaSignature() throws Exception {
        when(userRepository.findById(userId)).thenReturn(Optional.of(testUser));
        when(blockchainRepo.findByDniHashOrderByCreatedAtDesc(any())).thenReturn(Collections.emptyList());
        when(deviceRepo.findByUserIdOrderByCreatedAtDesc(userId)).thenReturn(Collections.emptyList());
        when(oauthAuditRepo.findByUserIdHashOrderByCreatedAtDesc(any())).thenReturn(Collections.emptyList());

        Map<String, Object> export = userActivityService.exportUserActivity(userId, LocalDate.now().minusDays(5), LocalDate.now());

        assertNotNull(export);
        assertEquals("SHA256withRSA", export.get("signingAlgorithm"));
        assertEquals("JSON", export.get("exportFormat"));
        assertNotNull(export.get("integrityHashSha256"));
        assertNotNull(export.get("signature"));

        // Verify RSA signature of payload
        String signatureBase64 = (String) export.get("signature");
        byte[] sigBytes = Base64.getDecoder().decode(signatureBase64);

        com.fasterxml.jackson.databind.ObjectMapper mapper = new com.fasterxml.jackson.databind.ObjectMapper();
        String payloadJson = mapper.writeValueAsString(export.get("payload"));

        Signature sig = Signature.getInstance("SHA256withRSA");
        sig.initVerify(publicKey);
        sig.update(payloadJson.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        assertTrue(sig.verify(sigBytes), "La firma digital RSA sobre el payload debe ser válida");

        // Verify audit log entry was created
        verify(oauthAuditRepo, atLeastOnce()).save(any(OAuthAuditLog.class));
    }
}
