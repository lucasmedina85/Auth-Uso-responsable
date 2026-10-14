package com.authenticator.service;

import com.authenticator.domain.OAuthAuditLog;
import com.authenticator.domain.TrustedDevice;
import com.authenticator.domain.TrustedDeviceStatus;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.DeviceAlertResponse;
import com.authenticator.dto.DeviceRegistrationRequest;
import com.authenticator.dto.DeviceResponse;
import com.authenticator.repository.OAuthAuditLogRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.LocalDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class DeviceService {

    private final TrustedDeviceRepository deviceRepository;
    private final UserRepository userRepository;
    private final OAuthAuditLogRepository auditLogRepository;
    private final BlacklistService blacklistService;

    @Value("${app.devices.hmac-secret:${DEVICE_HMAC_SECRET:dev-dummy-device-hmac-secret-at-least-256-bits}}")
    private String deviceHmacSecret;

    @Value("${app.devices.max-per-user:5}")
    private int maxDevicesPerUser;

    @Value("${app.devices.min-age-hours:24}")
    private int minAgeHours;

    @Value("${app.oauth.audit-secret:${app.oauth.pairwise-secret:dev-audit-secret}}")
    private String auditSecret;

    public DeviceService(TrustedDeviceRepository deviceRepository,
                         UserRepository userRepository,
                         OAuthAuditLogRepository auditLogRepository,
                         BlacklistService blacklistService) {
        this.deviceRepository = deviceRepository;
        this.userRepository = userRepository;
        this.auditLogRepository = auditLogRepository;
        this.blacklistService = blacklistService;
    }

    public String computeDeviceHash(String rawDeviceId) {
        if (rawDeviceId == null || rawDeviceId.isBlank()) {
            return null;
        }
        return hmacSha256(rawDeviceId.trim(), deviceHmacSecret);
    }

    private String hmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] bytes = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error computing HMAC-SHA256", e);
        }
    }

    @Transactional
    public DeviceResponse registerDevice(UUID userId, DeviceRegistrationRequest request) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Usuario no encontrado"));

        String deviceHash = computeDeviceHash(request.getDeviceId());

        Optional<TrustedDevice> existing = deviceRepository.findByUserIdAndDeviceHash(userId, deviceHash);
        if (existing.isPresent()) {
            TrustedDevice dev = existing.get();
            dev.setLastSeenAt(LocalDateTime.now());
            if (request.getDeviceName() != null && !request.getDeviceName().isBlank()) {
                dev.setDeviceName(request.getDeviceName());
            }
            if (request.getManufacturer() != null && !request.getManufacturer().isBlank()) {
                dev.setManufacturer(request.getManufacturer());
            }
            if (request.getOsVersion() != null && !request.getOsVersion().isBlank()) {
                dev.setOsVersion(request.getOsVersion());
            }
            if (request.getDeviceType() != null && !request.getDeviceType().isBlank()) {
                dev.setDeviceType(request.getDeviceType());
            }
            TrustedDevice saved = deviceRepository.save(dev);
            return mapToResponse(saved, true);
        }

        // Validar máximo de dispositivos por usuario
        long activeCount = deviceRepository.countByUserIdAndStatusNot(userId, TrustedDeviceStatus.REVOKED);
        if (activeCount >= maxDevicesPerUser) {
            throw new IllegalArgumentException("Límite de dispositivos alcanzado (máximo " + maxDevicesPerUser + ")");
        }

        // Regla de confianza:
        // El primer dispositivo del usuario pasa a TRUSTED si tiene identidad verificada y sin alertas.
        // Los siguientes quedan PENDING hasta aprobación por un dispositivo TRUSTED existente.
        TrustedDeviceStatus initialStatus = TrustedDeviceStatus.PENDING;
        LocalDateTime trustEvaluatedAt = null;

        boolean isUserVerified = (user.getStatus() == UserStatus.LOCALLY_VERIFIED || user.getStatus() == UserStatus.VERIFIED);
        boolean hasFraudOrBlacklist = (user.getDniHash() != null && blacklistService.isDniBlacklisted(user.getDniHash()))
                || (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now()));

        if (activeCount == 0 && isUserVerified && !hasFraudOrBlacklist) {
            initialStatus = TrustedDeviceStatus.TRUSTED;
            trustEvaluatedAt = LocalDateTime.now();
        }

        TrustedDevice newDevice = TrustedDevice.builder()
                .user(user)
                .deviceHash(deviceHash)
                .deviceName(request.getDeviceName() != null ? request.getDeviceName() : "Dispositivo")
                .manufacturer(request.getManufacturer() != null ? request.getManufacturer() : "Desconocido")
                .osVersion(request.getOsVersion() != null ? request.getOsVersion() : "Desconocido")
                .deviceType(request.getDeviceType() != null ? request.getDeviceType() : "MOBILE")
                .status(initialStatus)
                .firstSeenAt(LocalDateTime.now())
                .lastSeenAt(LocalDateTime.now())
                .trustEvaluatedAt(trustEvaluatedAt)
                .build();

        TrustedDevice saved = deviceRepository.save(newDevice);

        // Registro de auditoría
        OAuthAuditLog auditLog = new OAuthAuditLog();
        auditLog.setEventType("DEVICE_REGISTERED");
        auditLog.setClientId("SIP_APP");
        auditLog.setUserIdHash(hmacSha256(user.getId().toString(), auditSecret));
        auditLog.setDetails("Registro de dispositivo: status=" + initialStatus + ", hash=" + deviceHash);
        auditLogRepository.save(auditLog);

        return mapToResponse(saved, true);
    }

    @Transactional
    public DeviceResponse approveDevice(UUID userId, UUID deviceId, String approverDeviceId) {
        TrustedDevice targetDevice = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new IllegalArgumentException("Dispositivo no encontrado"));

        // Verificación anti-IDOR
        if (!targetDevice.getUser().getId().equals(userId)) {
            throw new SecurityException("Acceso no autorizado: el dispositivo no pertenece al usuario autenticado");
        }

        // Verificar que el aprobador sea un dispositivo TRUSTED del usuario
        if (approverDeviceId == null || approverDeviceId.isBlank()) {
            throw new SecurityException("Se requiere el identificador del dispositivo aprobador");
        }
        String approverHash = computeDeviceHash(approverDeviceId);
        TrustedDevice approver = deviceRepository.findByUserIdAndDeviceHash(userId, approverHash)
                .orElseThrow(() -> new SecurityException("Dispositivo aprobador no reconocido"));

        if (approver.getStatus() != TrustedDeviceStatus.TRUSTED) {
            throw new SecurityException("Solo un dispositivo en estado TRUSTED puede aprobar nuevos dispositivos");
        }

        targetDevice.setStatus(TrustedDeviceStatus.TRUSTED);
        targetDevice.setTrustEvaluatedAt(LocalDateTime.now());
        TrustedDevice saved = deviceRepository.save(targetDevice);

        // Auditoría
        OAuthAuditLog auditLog = new OAuthAuditLog();
        auditLog.setEventType("DEVICE_APPROVED");
        auditLog.setClientId("SIP_APP");
        auditLog.setUserIdHash(hmacSha256(userId.toString(), auditSecret));
        auditLog.setDetails("Dispositivo aprobado por: " + approver.getDeviceHash() + " para target=" + targetDevice.getDeviceHash());
        auditLogRepository.save(auditLog);

        return mapToResponse(saved, false);
    }

    @Transactional
    public void revokeDevice(UUID userId, UUID deviceId) {
        TrustedDevice targetDevice = deviceRepository.findById(deviceId)
                .orElseThrow(() -> new IllegalArgumentException("Dispositivo no encontrado"));

        // Verificación anti-IDOR
        if (!targetDevice.getUser().getId().equals(userId)) {
            throw new SecurityException("Acceso no autorizado: el dispositivo no pertenece al usuario autenticado");
        }

        targetDevice.setStatus(TrustedDeviceStatus.REVOKED);
        targetDevice.setRevokedAt(LocalDateTime.now());
        deviceRepository.save(targetDevice);

        // Auditoría
        OAuthAuditLog auditLog = new OAuthAuditLog();
        auditLog.setEventType("DEVICE_REVOKED");
        auditLog.setClientId("SIP_APP");
        auditLog.setUserIdHash(hmacSha256(userId.toString(), auditSecret));
        auditLog.setDetails("Dispositivo revocado: hash=" + targetDevice.getDeviceHash());
        auditLogRepository.save(auditLog);
    }

    @Transactional(readOnly = true)
    public List<DeviceResponse> getDevices(UUID userId, String currentDeviceId) {
        String currentHash = computeDeviceHash(currentDeviceId);
        List<TrustedDevice> list = deviceRepository.findByUserIdOrderByCreatedAtDesc(userId);
        return list.stream()
                .map(d -> mapToResponse(d, currentHash != null && currentHash.equals(d.getDeviceHash())))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<DeviceAlertResponse> getAlerts(UUID userId, String currentDeviceId) {
        if (currentDeviceId == null || currentDeviceId.isBlank()) {
            return Collections.emptyList();
        }
        String currentHash = computeDeviceHash(currentDeviceId);
        Optional<TrustedDevice> current = deviceRepository.findByUserIdAndDeviceHash(userId, currentHash);
        if (current.isEmpty() || current.get().getStatus() != TrustedDeviceStatus.TRUSTED) {
            return Collections.emptyList();
        }

        List<TrustedDevice> devices = deviceRepository.findByUserIdOrderByCreatedAtDesc(userId);
        List<DeviceAlertResponse> alerts = new ArrayList<>();
        LocalDateTime cutoff = LocalDateTime.now().minusHours(24);

        for (TrustedDevice d : devices) {
            if (d.getStatus() == TrustedDeviceStatus.PENDING) {
                alerts.add(DeviceAlertResponse.builder()
                        .id(d.getId())
                        .deviceName(d.getDeviceName())
                        .type("PENDING_APPROVAL")
                        .message("Nuevo dispositivo pendiente de aprobación: " + d.getDeviceName())
                        .timestamp(d.getCreatedAt())
                        .build());
            } else if (d.getStatus() == TrustedDeviceStatus.REVOKED && d.getRevokedAt() != null && d.getRevokedAt().isAfter(cutoff)) {
                alerts.add(DeviceAlertResponse.builder()
                        .id(d.getId())
                        .deviceName(d.getDeviceName())
                        .type("DEVICE_REVOKED")
                        .message("Dispositivo revocado recientemente: " + d.getDeviceName())
                        .timestamp(d.getRevokedAt())
                        .build());
            }
        }
        return alerts;
    }

    private DeviceResponse mapToResponse(TrustedDevice d, boolean isCurrent) {
        return DeviceResponse.builder()
                .id(d.getId())
                .deviceHash(d.getDeviceHash())
                .deviceName(d.getDeviceName())
                .manufacturer(d.getManufacturer())
                .osVersion(d.getOsVersion())
                .deviceType(d.getDeviceType())
                .status(d.getStatus())
                .isCurrent(isCurrent)
                .firstSeenAt(d.getFirstSeenAt())
                .lastSeenAt(d.getLastSeenAt())
                .trustEvaluatedAt(d.getTrustEvaluatedAt())
                .revokedAt(d.getRevokedAt())
                .build();
    }
}
