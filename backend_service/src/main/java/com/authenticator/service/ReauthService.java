package com.authenticator.service;

import com.authenticator.domain.User;
import com.authenticator.dto.ReauthRequest;
import com.authenticator.dto.ReauthResponse;
import com.authenticator.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class ReauthService {

    private static final Logger log = LoggerFactory.getLogger(ReauthService.class);

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final RateLimitingService rateLimitingService;
    private final AuthAuditService authAuditService;

    @Value("${app.auth.reauth-token-validity-seconds:120}")
    private long reauthTokenValiditySeconds;

    public static class ReauthEntry {
        final String token;
        final UUID userId;
        final String purpose;
        final LocalDateTime expiresAt;
        volatile boolean used = false;

        public ReauthEntry(String token, UUID userId, String purpose, LocalDateTime expiresAt) {
            this.token = token;
            this.userId = userId;
            this.purpose = purpose;
            this.expiresAt = expiresAt;
        }
    }

    private final Map<String, ReauthEntry> reauthStore = new ConcurrentHashMap<>();

    public ReauthService(UserRepository userRepository,
                         PasswordEncoder passwordEncoder,
                         RateLimitingService rateLimitingService,
                         AuthAuditService authAuditService) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.rateLimitingService = rateLimitingService;
        this.authAuditService = authAuditService;
    }

    @Transactional(noRollbackFor = SecurityException.class)
    public ReauthResponse reauthenticate(UUID userId, ReauthRequest request, String clientIp, String rawDeviceId) {
        // Rate limiting por IP y por usuario
        if (!rateLimitingService.tryConsume("reauth-ip:" + clientIp)) {
            throw new SecurityException("Demasiados intentos de reautenticación desde esta IP. Intente más tarde.");
        }
        if (!rateLimitingService.tryConsume("reauth-user:" + userId)) {
            throw new SecurityException("Demasiados intentos de reautenticación para esta cuenta. Intente más tarde.");
        }

        User user = userRepository.findById(userId)
                .orElseThrow(() -> new SecurityException("Usuario no encontrado"));

        LocalDateTime now = LocalDateTime.now();
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(now)) {
            authAuditService.recordAuthEvent(user, user.getEmail(), "REAUTH_FAILED", "BLOCKED", clientIp, rawDeviceId);
            throw new SecurityException("Cuenta bloqueada temporalmente por seguridad");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            user.setFailedLoginAttempts(user.getFailedLoginAttempts() + 1);
            if (user.getFailedLoginAttempts() >= 5) {
                user.setLockedUntil(now.plusMinutes(15));
            }
            userRepository.save(user);

            authAuditService.recordAuthEvent(user, user.getEmail(), "REAUTH_FAILED", "FAILURE", clientIp, rawDeviceId);
            throw new SecurityException("Contraseña inválida para reautenticación");
        }

        // Éxito: resetear intentos fallidos
        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        authAuditService.recordAuthEvent(user, user.getEmail(), "REAUTH_SUCCESS", "SUCCESS", clientIp, rawDeviceId);

        // Generar token opaco de un solo uso
        String reauthToken = generateReauthToken(userId, "EXPORT");

        return ReauthResponse.builder()
                .reauthToken(reauthToken)
                .expiresInSeconds(reauthTokenValiditySeconds)
                .purpose("EXPORT")
                .build();
    }

    public String generateReauthToken(UUID userId, String purpose) {
        String token = "reauth-" + UUID.randomUUID() + "-" + UUID.randomUUID();
        ReauthEntry entry = new ReauthEntry(token, userId, purpose, LocalDateTime.now().plusSeconds(reauthTokenValiditySeconds));
        reauthStore.put(token, entry);
        return token;
    }

    /**
     * Valida y consume el token de reautenticación de un solo uso.
     * Retorna true si es válido y no fue consumido, o false en caso contrario.
     */
    public boolean validateAndConsumeReauthToken(UUID userId, String token, String requiredPurpose) {
        if (token == null || token.isBlank()) {
            return false;
        }

        ReauthEntry entry = reauthStore.remove(token);
        if (entry == null || entry.used) {
            return false;
        }

        if (entry.expiresAt.isBefore(LocalDateTime.now())) {
            return false;
        }

        if (!entry.userId.equals(userId)) {
            return false;
        }

        if (!entry.purpose.equalsIgnoreCase(requiredPurpose)) {
            return false;
        }

        entry.used = true;
        return true;
    }
}
