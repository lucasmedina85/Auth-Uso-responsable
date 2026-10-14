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
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class UserActivityService {

    private static final Logger log = LoggerFactory.getLogger(UserActivityService.class);

    private final UserRepository userRepository;
    private final BlockchainAuditLogRepository blockchainRepo;
    private final TrustedDeviceRepository deviceRepo;
    private final OAuthAuditLogRepository oauthAuditRepo;
    private final AuthAuditLogRepository authAuditRepo;
    private final ExportSigningKeyManager exportSigningKeyManager;
    private final ObjectMapper objectMapper = new ObjectMapper()
            .registerModule(new com.fasterxml.jackson.datatype.jsr310.JavaTimeModule());

    @Value("${app.oauth.audit-secret:${app.oauth.pairwise-secret:${OAUTH_AUDIT_SECRET:dev-audit-secret}}}")
    private String auditSecret;

    @Value("${app.export.max-range-days:90}")
    private int maxRangeDays;

    @Value("${app.export.max-records:500}")
    private int maxRecords;

    public UserActivityService(UserRepository userRepository,
                               BlockchainAuditLogRepository blockchainRepo,
                               TrustedDeviceRepository deviceRepo,
                               OAuthAuditLogRepository oauthAuditRepo,
                               AuthAuditLogRepository authAuditRepo,
                               ExportSigningKeyManager exportSigningKeyManager) {
        this.userRepository = userRepository;
        this.blockchainRepo = blockchainRepo;
        this.deviceRepo = deviceRepo;
        this.oauthAuditRepo = oauthAuditRepo;
        this.authAuditRepo = authAuditRepo;
        this.exportSigningKeyManager = exportSigningKeyManager;
    }

    @Transactional(readOnly = true)
    public UserActivityPageResponse getUserActivity(UUID userId,
                                                    int page,
                                                    int size,
                                                    String typeFilter,
                                                    LocalDate startDate,
                                                    LocalDate endDate) {
        // Clamping de página y tamaño
        int clampedPage = Math.max(0, page);
        int clampedSize = Math.min(Math.max(1, size), 50);

        // Validación de fechas
        if (startDate != null && endDate != null) {
            if (startDate.isAfter(endDate)) {
                throw new IllegalArgumentException("La fecha 'from' no puede ser posterior a 'to'");
            }
            if (endDate.isAfter(LocalDate.now())) {
                throw new IllegalArgumentException("La fecha 'to' no puede ser futura");
            }
            if (ChronoUnit.DAYS.between(startDate, endDate) > maxRangeDays) {
                throw new IllegalArgumentException("El rango de fechas no puede superar los " + maxRangeDays + " días");
            }
        }

        List<UserActivityEventDTO> allEvents = collectUserEvents(userId);

        // Filtrado por tipo
        List<UserActivityEventDTO> filtered = allEvents.stream()
                .filter(e -> {
                    if (typeFilter == null || typeFilter.isBlank() || "ALL".equalsIgnoreCase(typeFilter)) {
                        return true;
                    }
                    return typeFilter.equalsIgnoreCase(e.getType());
                })
                .filter(e -> {
                    if (startDate == null) return true;
                    return !e.getTimestamp().toLocalDate().isBefore(startDate);
                })
                .filter(e -> {
                    if (endDate == null) return true;
                    return !e.getTimestamp().toLocalDate().isAfter(endDate);
                })
                .sorted(Comparator.comparing(UserActivityEventDTO::getTimestamp).reversed())
                .collect(Collectors.toList());

        int totalElements = filtered.size();
        int totalPages = clampedSize > 0 ? (int) Math.ceil((double) totalElements / clampedSize) : 1;
        int fromIndex = Math.min(Math.max(0, clampedPage * clampedSize), totalElements);
        int toIndex = Math.min(fromIndex + clampedSize, totalElements);
        List<UserActivityEventDTO> pagedEvents = filtered.subList(fromIndex, toIndex);

        return UserActivityPageResponse.builder()
                .events(pagedEvents)
                .page(clampedPage)
                .size(clampedSize)
                .totalElements(totalElements)
                .totalPages(totalPages)
                .hasNext(toIndex < totalElements)
                .build();
    }

    @Transactional
    public Map<String, Object> exportUserActivity(UUID userId, LocalDate startDate, LocalDate endDate) {
        LocalDate today = LocalDate.now();
        if (endDate == null) {
            endDate = today;
        }
        if (startDate == null) {
            startDate = endDate.minusDays(maxRangeDays);
        }

        if (startDate.isAfter(endDate)) {
            throw new IllegalArgumentException("La fecha 'from' no puede ser posterior a 'to'");
        }
        if (endDate.isAfter(today)) {
            throw new IllegalArgumentException("La fecha 'to' no puede ser futura");
        }
        if (ChronoUnit.DAYS.between(startDate, endDate) > maxRangeDays) {
            throw new IllegalArgumentException("El rango de fechas no puede superar los " + maxRangeDays + " días");
        }

        final LocalDate finalStart = startDate;
        final LocalDate finalEnd = endDate;

        List<UserActivityEventDTO> events = collectUserEvents(userId).stream()
                .filter(e -> !e.getTimestamp().toLocalDate().isBefore(finalStart))
                .filter(e -> !e.getTimestamp().toLocalDate().isAfter(finalEnd))
                .sorted(Comparator.comparing(UserActivityEventDTO::getTimestamp).reversed())
                .collect(Collectors.toList());

        int totalMatching = events.size();
        boolean truncated = false;
        if (totalMatching > maxRecords) {
            truncated = true;
            events = events.subList(0, maxRecords);
        }

        String userHash = hmacSha256(userId.toString(), auditSecret);

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("userPseudonym", userHash.length() >= 16 ? userHash.substring(0, 16) : userHash);
        payload.put("dateRange", startDate + " a " + endDate);
        payload.put("generatedAt", LocalDateTime.now().toString());
        payload.put("schemaVersion", "1.0.0");
        payload.put("totalRecords", events.size());
        payload.put("truncated", truncated);
        payload.put("totalMatchingRecords", totalMatching);
        payload.put("exportedRecords", events.size());
        payload.put("records", events);

        // Registrar en auditoría la exportación de actividad
        OAuthAuditLog exportAudit = new OAuthAuditLog();
        exportAudit.setEventType("ACCOUNT_ACTIVITY_EXPORTED");
        exportAudit.setClientId("system");
        exportAudit.setUserIdHash(userHash);
        exportAudit.setDetails("Exportación forense de actividad de cuenta generada por el usuario");
        oauthAuditRepo.save(exportAudit);

        String canonicalJson;
        try {
            canonicalJson = objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new RuntimeException("Error serializando export de actividad a JSON", e);
        }

        String integrityHash = sha256Hex(canonicalJson);
        String signature = exportSigningKeyManager.sign(canonicalJson);

        Map<String, Object> response = new LinkedHashMap<>(payload);
        response.put("payload", payload);
        response.put("exportFormat", "JSON");
        response.put("integrityHashSha256", integrityHash);
        response.put("signature", signature);
        response.put("signingAlgorithm", "SHA256withRSA");
        response.put("keyId", exportSigningKeyManager.getPrimaryKeyId());

        return response;
    }

    private List<UserActivityEventDTO> collectUserEvents(UUID userId) {
        List<UserActivityEventDTO> events = new ArrayList<>();
        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            return events;
        }
        User user = userOpt.get();

        // 1. Eventos de Autenticación Reales desde auth_audit_logs (CU-0035 / Login / Lockouts / Logout)
        List<AuthAuditLog> authLogs = authAuditRepo.findByUserIdOrderByCreatedAtDesc(userId);
        for (AuthAuditLog a : authLogs) {
            String desc;
            switch (a.getEventType()) {
                case "LOGIN_SUCCESS" -> desc = "Inicio de sesión exitoso";
                case "LOGIN_FAILED" -> desc = "Intento de inicio de sesión fallido";
                case "ACCOUNT_LOCKED" -> desc = "Bloqueo temporal de cuenta por reiterados fallos";
                case "LOGOUT" -> desc = "Cierre de sesión de la cuenta";
                case "REAUTH_SUCCESS" -> desc = "Reautenticación exitosa para exportación";
                case "REAUTH_FAILED" -> desc = "Reautenticación fallida";
                default -> desc = "Evento de autenticación: " + a.getEventType();
            }
            events.add(UserActivityEventDTO.builder()
                    .id("auth-" + a.getId())
                    .timestamp(a.getCreatedAt())
                    .type("LOGIN")
                    .description(desc)
                    .result(a.getResult())
                    .maskedIp(a.getMaskedIp())
                    .metadata(a.getDeviceHash() != null ? Map.of("deviceHash", a.getDeviceHash()) : null)
                    .build());
        }

        if (user.getCreatedAt() != null && authLogs.isEmpty()) {
            events.add(UserActivityEventDTO.builder()
                    .id("user-created-" + user.getId())
                    .timestamp(user.getCreatedAt())
                    .type("LOGIN")
                    .description("Registro de cuenta e inicio inicial")
                    .result("SUCCESS")
                    .build());
        }

        if (user.getVerifiedAt() != null) {
            events.add(UserActivityEventDTO.builder()
                    .id("user-verified-" + user.getId())
                    .timestamp(user.getVerifiedAt())
                    .type("VALIDATION")
                    .description("Validación de identidad oficial completada")
                    .result("SUCCESS")
                    .build());
        }

        if (user.getLockedUntil() != null) {
            events.add(UserActivityEventDTO.builder()
                    .id("user-locked-" + user.getId() + "-" + user.getUpdatedAt())
                    .timestamp(user.getUpdatedAt() != null ? user.getUpdatedAt() : LocalDateTime.now())
                    .type("SECURITY")
                    .description("Bloqueo preventivo de cuenta por intentos fallidos")
                    .result("BLOCKED")
                    .build());
        }

        // 2. Evaluaciones de Riesgo y Blockchain
        if (user.getDniHash() != null) {
            List<BlockchainAuditLog> bLogs = blockchainRepo.findByDniHashOrderByCreatedAtDesc(user.getDniHash());
            for (BlockchainAuditLog b : bLogs) {
                String decision = b.getDecision() != null ? b.getDecision() : "DESCONOCIDO";
                String result = "AUTORIZAR".equalsIgnoreCase(decision) ? "SUCCESS" :
                                ("BLOQUEAR".equalsIgnoreCase(decision) ? "BLOCKED" : "REVIEW");
                String txRef = b.getTransactionHash() != null ? b.getTransactionHash() :
                               (b.getSessionHash() != null && b.getSessionHash().length() >= 16 ? "0x" + b.getSessionHash().substring(0, 16) : null);

                events.add(UserActivityEventDTO.builder()
                        .id("blockchain-eval-" + b.getId())
                        .timestamp(b.getCreatedAt())
                        .type("VALIDATION")
                        .decision(decision)
                        .description("Evaluación de riesgo operacional: " + decision)
                        .result(result)
                        .maskedIp(b.getMaskedIp())
                        .txRef(txRef)
                        .metadata(Map.of(
                                "score", b.getScore(),
                                "status", b.getStatus() != null ? b.getStatus().name() : "RECORDED"
                        ))
                        .build());
            }
        }

        // 3. Dispositivos Confiables
        List<TrustedDevice> devices = deviceRepo.findByUserIdOrderByCreatedAtDesc(userId);
        for (TrustedDevice dev : devices) {
            events.add(UserActivityEventDTO.builder()
                    .id("device-reg-" + dev.getId())
                    .timestamp(dev.getCreatedAt())
                    .type("DEVICE")
                    .description("Dispositivo registrado: " + (dev.getDeviceName() != null ? dev.getDeviceName() : "Móvil"))
                    .result("SUCCESS")
                    .metadata(Map.of("status", dev.getStatus().name()))
                    .build());

            if (dev.getRevokedAt() != null) {
                events.add(UserActivityEventDTO.builder()
                        .id("device-rev-" + dev.getId())
                        .timestamp(dev.getRevokedAt())
                        .type("DEVICE")
                        .description("Dispositivo revocado: " + (dev.getDeviceName() != null ? dev.getDeviceName() : "Móvil"))
                        .result("REVOKED")
                        .metadata(Map.of("status", "REVOKED"))
                        .build());
            }
        }

        // 4. Auditoría OAuth
        String userHash = hmacSha256(userId.toString(), auditSecret);
        List<OAuthAuditLog> oauthLogs = oauthAuditRepo.findByUserIdHashOrderByCreatedAtDesc(userHash);
        for (OAuthAuditLog oLog : oauthLogs) {
            String eventType = oLog.getEventType();
            String result = "APP_UNLINKED".equalsIgnoreCase(eventType) ? "REVOKED" : "SUCCESS";
            events.add(UserActivityEventDTO.builder()
                    .id("oauth-audit-" + oLog.getId())
                    .timestamp(oLog.getCreatedAt())
                    .type("OAUTH")
                    .description("OAuth [" + oLog.getClientId() + "]: " + oLog.getEventType())
                    .result(result)
                    .metadata(Map.of(
                            "clientId", oLog.getClientId(),
                            "details", oLog.getDetails() != null ? oLog.getDetails() : ""
                    ))
                    .build());
        }

        return events;
    }

    private String sha256Hex(String data) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] hash = md.digest(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hash.length * 2);
            for (byte b : hash) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error calculando SHA-256", e);
        }
    }

    private String hmacSha256(String data, String key) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            SecretKeySpec keySpec = new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
            mac.init(keySpec);
            byte[] raw = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(raw.length * 2);
            for (byte b : raw) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error calculando HMAC-SHA256", e);
        }
    }
}
