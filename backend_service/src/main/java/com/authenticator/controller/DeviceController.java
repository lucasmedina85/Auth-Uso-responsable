package com.authenticator.controller;

import com.authenticator.dto.DeviceAlertResponse;
import com.authenticator.dto.DeviceRegistrationRequest;
import com.authenticator.dto.DeviceResponse;
import com.authenticator.service.DeviceService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/devices")
public class DeviceController {

    private final DeviceService deviceService;

    public DeviceController(DeviceService deviceService) {
        this.deviceService = deviceService;
    }

    private UUID getAuthenticatedUserId(Authentication authentication) {
        if (authentication == null || authentication.getPrincipal() == null) {
            throw new SecurityException("Usuario no autenticado");
        }
        return UUID.fromString((String) authentication.getPrincipal());
    }

    @GetMapping
    public ResponseEntity<List<DeviceResponse>> getDevices(
            Authentication authentication,
            @RequestHeader(value = "X-Device-Id", required = false) String deviceId) {
        UUID userId = getAuthenticatedUserId(authentication);
        return ResponseEntity.ok(deviceService.getDevices(userId, deviceId));
    }

    @PostMapping("/register")
    public ResponseEntity<DeviceResponse> registerDevice(
            Authentication authentication,
            @Valid @RequestBody DeviceRegistrationRequest request) {
        UUID userId = getAuthenticatedUserId(authentication);
        return ResponseEntity.status(HttpStatus.CREATED).body(deviceService.registerDevice(userId, request));
    }

    @PostMapping("/{id}/approve")
    public ResponseEntity<DeviceResponse> approveDevice(
            Authentication authentication,
            @PathVariable UUID id,
            @RequestHeader(value = "X-Device-Id", required = false) String deviceId) {
        UUID userId = getAuthenticatedUserId(authentication);
        try {
            return ResponseEntity.ok(deviceService.approveDevice(userId, id, deviceId));
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
    }

    @PostMapping("/{id}/revoke")
    public ResponseEntity<Void> revokeDevice(
            Authentication authentication,
            @PathVariable UUID id) {
        UUID userId = getAuthenticatedUserId(authentication);
        try {
            deviceService.revokeDevice(userId, id);
            return ResponseEntity.ok().build();
        } catch (SecurityException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
    }

    @GetMapping("/alerts")
    public ResponseEntity<List<DeviceAlertResponse>> getAlerts(
            Authentication authentication,
            @RequestHeader(value = "X-Device-Id", required = false) String deviceId) {
        UUID userId = getAuthenticatedUserId(authentication);
        return ResponseEntity.ok(deviceService.getAlerts(userId, deviceId));
    }
}
