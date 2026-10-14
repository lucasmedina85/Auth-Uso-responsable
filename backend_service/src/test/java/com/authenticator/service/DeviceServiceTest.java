package com.authenticator.service;

import com.authenticator.domain.TrustedDeviceStatus;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.DeviceAlertResponse;
import com.authenticator.dto.DeviceRegistrationRequest;
import com.authenticator.dto.DeviceResponse;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("test")
@Transactional
public class DeviceServiceTest {

    @Autowired
    private DeviceService deviceService;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TrustedDeviceRepository deviceRepository;

    @Autowired
    private OAuthAuditLogRepository auditLogRepository;

    private User verifiedUser;
    private User otherUser;

    @BeforeEach
    public void setup() {
        deviceRepository.deleteAll();
        auditLogRepository.deleteAll();
        userRepository.deleteAll();

        verifiedUser = new User();
        verifiedUser.setEmail("verified@example.com");
        verifiedUser.setPasswordHash("hash123");
        verifiedUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        verifiedUser = userRepository.save(verifiedUser);

        otherUser = new User();
        otherUser.setEmail("other@example.com");
        otherUser.setPasswordHash("hash456");
        otherUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        otherUser = userRepository.save(otherUser);
    }

    @Test
    public void testFirstDevice_VerifiedUser_BecomesTrusted() {
        DeviceRegistrationRequest req = DeviceRegistrationRequest.builder()
                .deviceId(UUID.randomUUID().toString())
                .deviceName("Pixel 8")
                .manufacturer("Google")
                .osVersion("Android 14")
                .deviceType("MOBILE")
                .build();

        DeviceResponse resp = deviceService.registerDevice(verifiedUser.getId(), req);

        assertNotNull(resp);
        assertEquals(TrustedDeviceStatus.TRUSTED, resp.getStatus());
        assertTrue(resp.isCurrent());
    }

    @Test
    public void testFirstDevice_UnverifiedUser_BecomesPending() {
        User unverified = new User();
        unverified.setEmail("unverified@example.com");
        unverified.setPasswordHash("hash");
        unverified.setStatus(UserStatus.REGISTERED);
        unverified = userRepository.save(unverified);

        DeviceRegistrationRequest req = DeviceRegistrationRequest.builder()
                .deviceId(UUID.randomUUID().toString())
                .deviceName("Galaxy S23")
                .build();

        DeviceResponse resp = deviceService.registerDevice(unverified.getId(), req);
        assertEquals(TrustedDeviceStatus.PENDING, resp.getStatus());
    }

    @Test
    public void testSecondDevice_BecomesPending_AndCanBeApprovedByFirstDevice() {
        String firstDeviceId = UUID.randomUUID().toString();
        DeviceRegistrationRequest req1 = DeviceRegistrationRequest.builder()
                .deviceId(firstDeviceId)
                .deviceName("Device 1")
                .build();
        DeviceResponse dev1 = deviceService.registerDevice(verifiedUser.getId(), req1);
        assertEquals(TrustedDeviceStatus.TRUSTED, dev1.getStatus());

        String secondDeviceId = UUID.randomUUID().toString();
        DeviceRegistrationRequest req2 = DeviceRegistrationRequest.builder()
                .deviceId(secondDeviceId)
                .deviceName("Device 2")
                .build();
        DeviceResponse dev2 = deviceService.registerDevice(verifiedUser.getId(), req2);
        assertEquals(TrustedDeviceStatus.PENDING, dev2.getStatus());

        // Approve dev2 using dev1
        DeviceResponse approved = deviceService.approveDevice(verifiedUser.getId(), dev2.getId(), firstDeviceId);
        assertEquals(TrustedDeviceStatus.TRUSTED, approved.getStatus());
    }

    @Test
    public void testAntiIdor_CannotApproveOrRevokeDeviceOfOtherUser() {
        DeviceRegistrationRequest req = DeviceRegistrationRequest.builder()
                .deviceId(UUID.randomUUID().toString())
                .deviceName("Other's Phone")
                .build();
        DeviceResponse devOther = deviceService.registerDevice(otherUser.getId(), req);

        // verifiedUser attempts to revoke devOther
        assertThrows(SecurityException.class, () -> {
            deviceService.revokeDevice(verifiedUser.getId(), devOther.getId());
        });

        // verifiedUser attempts to approve devOther
        assertThrows(SecurityException.class, () -> {
            deviceService.approveDevice(verifiedUser.getId(), devOther.getId(), "some-id");
        });
    }

    @Test
    public void testIdempotentRegistration() {
        String devId = UUID.randomUUID().toString();
        DeviceRegistrationRequest req = DeviceRegistrationRequest.builder()
                .deviceId(devId)
                .deviceName("Initial Name")
                .build();

        DeviceResponse resp1 = deviceService.registerDevice(verifiedUser.getId(), req);
        assertEquals("Initial Name", resp1.getDeviceName());

        req.setDeviceName("Updated Name");
        DeviceResponse resp2 = deviceService.registerDevice(verifiedUser.getId(), req);

        assertEquals(resp1.getId(), resp2.getId());
        assertEquals("Updated Name", resp2.getDeviceName());
        assertEquals(1, deviceRepository.findByUserIdOrderByCreatedAtDesc(verifiedUser.getId()).size());
    }

    @Test
    public void testAlerts_ReportedToTrustedDevice() {
        String dev1Id = UUID.randomUUID().toString();
        deviceService.registerDevice(verifiedUser.getId(), DeviceRegistrationRequest.builder()
                .deviceId(dev1Id)
                .deviceName("Primary")
                .build());

        String dev2Id = UUID.randomUUID().toString();
        deviceService.registerDevice(verifiedUser.getId(), DeviceRegistrationRequest.builder()
                .deviceId(dev2Id)
                .deviceName("Secondary Pending")
                .build());

        List<DeviceAlertResponse> alerts = deviceService.getAlerts(verifiedUser.getId(), dev1Id);
        assertEquals(1, alerts.size());
        assertEquals("PENDING_APPROVAL", alerts.get(0).getType());
    }
}
