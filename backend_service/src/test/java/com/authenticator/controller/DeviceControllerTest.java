package com.authenticator.controller;

import com.authenticator.domain.TrustedDevice;
import com.authenticator.domain.TrustedDeviceStatus;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.DeviceRegistrationRequest;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class DeviceControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private TrustedDeviceRepository deviceRepository;

    @Autowired
    private com.authenticator.service.DeviceService deviceService;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private User user1;
    private User user2;
    private String tokenUser1;
    private String tokenUser2;

    @BeforeEach
    public void setup() {
        deviceRepository.deleteAll();
        userRepository.deleteAll();

        user1 = new User();
        user1.setEmail("user1@example.com");
        user1.setPasswordHash("hash1");
        user1.setStatus(UserStatus.LOCALLY_VERIFIED);
        user1 = userRepository.save(user1);

        user2 = new User();
        user2.setEmail("user2@example.com");
        user2.setPasswordHash("hash2");
        user2.setStatus(UserStatus.LOCALLY_VERIFIED);
        user2 = userRepository.save(user2);

        tokenUser1 = jwtUtil.generateAccessToken(user1.getId().toString());
        tokenUser2 = jwtUtil.generateAccessToken(user2.getId().toString());
    }

    @Test
    public void registerDevice_Success() throws Exception {
        DeviceRegistrationRequest req = DeviceRegistrationRequest.builder()
                .deviceId(UUID.randomUUID().toString())
                .deviceName("Pixel 8")
                .manufacturer("Google")
                .osVersion("Android 14")
                .deviceType("MOBILE")
                .build();

        mockMvc.perform(post("/devices/register")
                .header("Authorization", "Bearer " + tokenUser1)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.deviceName").value("Pixel 8"))
                .andExpect(jsonPath("$.status").value("TRUSTED"));
    }

    @Test
    public void getDevices_ReturnsOnlyUserDevices() throws Exception {
        TrustedDevice dev1 = TrustedDevice.builder()
                .user(user1)
                .deviceHash("hash1")
                .deviceName("Device User 1")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        deviceRepository.save(dev1);

        TrustedDevice dev2 = TrustedDevice.builder()
                .user(user2)
                .deviceHash("hash2")
                .deviceName("Device User 2")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        deviceRepository.save(dev2);

        mockMvc.perform(get("/devices")
                .header("Authorization", "Bearer " + tokenUser1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].deviceName").value("Device User 1"));
    }

    @Test
    public void antiIdor_UserCannotRevokeOtherUserDevice() throws Exception {
        TrustedDevice dev2 = TrustedDevice.builder()
                .user(user2)
                .deviceHash("hash2")
                .deviceName("Device User 2")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        dev2 = deviceRepository.save(dev2);

        // user1 tries to revoke user2's device
        mockMvc.perform(post("/devices/" + dev2.getId() + "/revoke")
                .header("Authorization", "Bearer " + tokenUser1))
                .andExpect(status().isForbidden());

        // Device remains TRUSTED
        TrustedDevice reloaded = deviceRepository.findById(dev2.getId()).get();
        assertEquals(TrustedDeviceStatus.TRUSTED, reloaded.getStatus());
    }

    @Test
    public void getSecurityScore_Endpoint_Success() throws Exception {
        mockMvc.perform(get("/users/security-score?hasBiometrics=true&hasScreenLock=true")
                .header("Authorization", "Bearer " + tokenUser1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.score").isNumber())
                .andExpect(jsonPath("$.level").isString())
                .andExpect(jsonPath("$.factors").isArray());
    }

    @Test
    public void filter_RevokedDevice_Receives401_WhileActiveDeviceContinuesFunctioning() throws Exception {
        String rawDeviceId1 = UUID.randomUUID().toString();
        String rawDeviceId2 = UUID.randomUUID().toString();

        TrustedDevice devRevoked = TrustedDevice.builder()
                .user(user1)
                .deviceHash(deviceService.computeDeviceHash(rawDeviceId1))
                .deviceName("Revoked Phone")
                .status(TrustedDeviceStatus.REVOKED)
                .build();
        deviceRepository.save(devRevoked);

        TrustedDevice devActive = TrustedDevice.builder()
                .user(user1)
                .deviceHash(deviceService.computeDeviceHash(rawDeviceId2))
                .deviceName("Active Phone")
                .status(TrustedDeviceStatus.TRUSTED)
                .build();
        deviceRepository.save(devActive);

        // 1. Petición desde el dispositivo revocado con X-Device-Id -> 401 con error DEVICE_REVOKED
        mockMvc.perform(get("/devices")
                .header("Authorization", "Bearer " + tokenUser1)
                .header("X-Device-Id", rawDeviceId1))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.error").value("DEVICE_REVOKED"))
                .andExpect(jsonPath("$.message").value("Dispositivo revocado"));

        // 2. Petición desde el dispositivo activo con X-Device-Id -> 200 OK
        mockMvc.perform(get("/devices")
                .header("Authorization", "Bearer " + tokenUser1)
                .header("X-Device-Id", rawDeviceId2))
                .andExpect(status().isOk());

        // 3. Petición sin cabecera X-Device-Id -> 200 OK (retrocompatibilidad)
        mockMvc.perform(get("/devices")
                .header("Authorization", "Bearer " + tokenUser1))
                .andExpect(status().isOk());
    }
}
