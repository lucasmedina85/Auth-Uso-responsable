package com.authenticator.service;

import com.authenticator.domain.AuthAuditLog;
import com.authenticator.domain.User;
import com.authenticator.repository.AuthAuditLogRepository;
import com.authenticator.util.MaskingUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class AuthAuditService {

    private static final Logger log = LoggerFactory.getLogger(AuthAuditService.class);

    private final AuthAuditLogRepository auditRepo;
    private final DeviceService deviceService;

    @Value("${app.audit.auth-retention-days:90}")
    private int retentionDays;

    @Value("${app.audit.max-inserts-per-minute:60}")
    private int maxInsertsPerMinute;

    // Rate limiter en memoria para evitar inflación de tabla por atacantes
    private final Map<String, WindowCounter> rateLimiters = new ConcurrentHashMap<>();

    private static class WindowCounter {
        long windowStartMinute;
        final AtomicInteger count = new AtomicInteger(0);

        WindowCounter(long minute) {
            this.windowStartMinute = minute;
        }
    }

    public AuthAuditService(AuthAuditLogRepository auditRepo, DeviceService deviceService) {
        this.auditRepo = auditRepo;
        this.deviceService = deviceService;
    }

    @Transactional
    public void recordAuthEvent(User user, String emailHmac, String eventType, String result, String clientIp, String rawDeviceId) {
        try {
            String maskedIp = MaskingUtils.maskIp(clientIp);
            String deviceHash = rawDeviceId != null ? deviceService.computeDeviceHash(rawDeviceId) : null;

            // Verificar límite de inserción por IP y email_hmac para mitigar ataques de inflación
            long currentMinute = System.currentTimeMillis() / 60000;
            String rateKey = (maskedIp != null ? maskedIp : "no-ip") + ":" + (emailHmac != null ? emailHmac : "no-email");
            WindowCounter counter = rateLimiters.compute(rateKey, (k, v) -> {
                if (v == null || v.windowStartMinute != currentMinute) {
                    WindowCounter nw = new WindowCounter(currentMinute);
                    nw.count.incrementAndGet();
                    return nw;
                }
                v.count.incrementAndGet();
                return v;
            });

            if (counter.count.get() > maxInsertsPerMinute) {
                log.warn("Límite de inserción de auditoría alcanzado para clave '{}'. Omitiendo registro para evitar inflación de tabla.", rateKey);
                return;
            }

            AuthAuditLog logEntry = AuthAuditLog.builder()
                    .user(user)
                    .emailHmac(emailHmac != null ? emailHmac : "")
                    .eventType(eventType)
                    .result(result)
                    .maskedIp(maskedIp)
                    .deviceHash(deviceHash)
                    .createdAt(LocalDateTime.now())
                    .build();

            auditRepo.save(logEntry);
        } catch (Exception e) {
            // Un fallo al escribir el log de auditoría nunca debe romper el flujo de autenticación
            log.error("Error al registrar auditoría de autenticación (evento '{}'): {}", eventType, e.getMessage());
        }
    }

    @Scheduled(cron = "${app.audit.purge-cron:0 0 3 * * *}")
    @Transactional
    public void purgeOldAuditLogs() {
        try {
            LocalDateTime cutoff = LocalDateTime.now().minusDays(retentionDays);
            int deleted = auditRepo.deleteOlderThan(cutoff);
            if (deleted > 0) {
                log.info("Purga de auditoría de autenticación ejecutada: {} registros anteriores a {} eliminados.", deleted, cutoff);
            }
        } catch (Exception e) {
            log.error("Error ejecutando purga periódica de auditoría de autenticación: {}", e.getMessage());
        }
    }
}
