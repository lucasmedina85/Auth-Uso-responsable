package com.authenticator.service;

import com.authenticator.domain.RefreshToken;
import com.authenticator.domain.RevokedToken;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.AuthResponse;
import com.authenticator.dto.LoginRequest;
import com.authenticator.dto.RefreshRequest;
import com.authenticator.dto.RegisterRequest;
import com.authenticator.repository.RefreshTokenRepository;
import com.authenticator.repository.RevokedTokenRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.authenticator.security.RevocationStore;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final RevokedTokenRepository revokedTokenRepository;
    private final RevocationStore revocationStore;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final long refreshTokenExpirationMs;
    private final String dummyHash;

    @Value("${app.auth.anti-enumeration-secret:${ANTI_ENUMERATION_SECRET:dev-dummy-anti-enum-secret-at-least-256-bits}}")
    private String antiEnumerationSecret;

    private static class NonExistentLoginTracker {
        int failedAttempts = 0;
        LocalDateTime lockedUntil = null;
    }

    private final Map<String, NonExistentLoginTracker> nonExistentLoginTrackers = new ConcurrentHashMap<>();

    public void resetNonExistentLoginTrackers() {
        nonExistentLoginTrackers.clear();
    }

    private final AuthAuditService authAuditService;

    @Autowired
    public AuthService(UserRepository userRepository, RefreshTokenRepository refreshTokenRepository,
                       RevokedTokenRepository revokedTokenRepository, RevocationStore revocationStore,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil, @Value("${app.jwt.refresh-token-expiration-ms:604800000}") long refreshTokenExpirationMs,
                       @Autowired(required = false) AuthAuditService authAuditService) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.revokedTokenRepository = revokedTokenRepository;
        this.revocationStore = revocationStore;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.refreshTokenExpirationMs = refreshTokenExpirationMs;
        this.authAuditService = authAuditService;
        this.dummyHash = passwordEncoder.encode("dummy");
    }

    public AuthService(UserRepository userRepository, RefreshTokenRepository refreshTokenRepository,
                       RevokedTokenRepository revokedTokenRepository, RevocationStore revocationStore,
                       PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil, long refreshTokenExpirationMs) {
        this(userRepository, refreshTokenRepository, revokedTokenRepository, revocationStore, passwordEncoder, jwtUtil, refreshTokenExpirationMs, null);
    }

    public String computeEmailHmac(String normalizedEmail) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            String secret = (antiEnumerationSecret != null && !antiEnumerationSecret.isBlank())
                    ? antiEnumerationSecret : "dev-dummy-anti-enum-secret-at-least-256-bits";
            mac.init(new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256"));
            byte[] bytes = mac.doFinal(normalizedEmail.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : bytes) {
                sb.append(String.format("%02x", b));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new RuntimeException("Error computing email HMAC for anti-enumeration", e);
        }
    }

    private String sha256(String data) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(data.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 not found", e);
        }
    }

    @Transactional
    public void register(RegisterRequest request) {
        if (userRepository.findByEmail(request.getEmail()).isPresent()) {
            throw new IllegalArgumentException("Email already exists");
        }
        User user = new User();
        user.setEmail(request.getEmail());
        user.setPasswordHash(passwordEncoder.encode(request.getPassword()));
        user.setStatus(UserStatus.REGISTERED);
        user.setRole("USER"); // Protección contra escalamiento / asignación masiva de roles
        userRepository.save(user);
    }

    @Transactional(noRollbackFor = SecurityException.class)
    public AuthResponse login(LoginRequest request) {
        return login(request, null, null);
    }

    @Transactional(noRollbackFor = SecurityException.class)
    public AuthResponse login(LoginRequest request, String clientIp, String rawDeviceId) {
        Optional<User> optUser = userRepository.findByEmail(request.getEmail());
        if (optUser.isEmpty()) {
            String normalizedEmail = request.getEmail() != null ? request.getEmail().trim().toLowerCase(Locale.ROOT) : "";
            String emailKey = computeEmailHmac(normalizedEmail);
            NonExistentLoginTracker tracker = nonExistentLoginTrackers.computeIfAbsent(emailKey, k -> new NonExistentLoginTracker());
            synchronized (tracker) {
                LocalDateTime now = LocalDateTime.now();
                if (tracker.lockedUntil != null && tracker.lockedUntil.isAfter(now)) {
                    passwordEncoder.matches(request.getPassword(), dummyHash);
                    if (authAuditService != null) {
                        authAuditService.recordAuthEvent(null, emailKey, "LOGIN_FAILED", "BLOCKED", clientIp, rawDeviceId);
                    }
                    throw new SecurityException("Cuenta bloqueada temporalmente");
                }
                if (tracker.lockedUntil != null && !tracker.lockedUntil.isAfter(now)) {
                    tracker.failedAttempts = 0;
                    tracker.lockedUntil = null;
                }

                passwordEncoder.matches(request.getPassword(), dummyHash);
                tracker.failedAttempts++;
                if (tracker.failedAttempts >= 5) {
                    tracker.lockedUntil = now.plusMinutes(15);
                    if (authAuditService != null) {
                        authAuditService.recordAuthEvent(null, emailKey, "ACCOUNT_LOCKED", "BLOCKED", clientIp, rawDeviceId);
                    }
                } else {
                    if (authAuditService != null) {
                        authAuditService.recordAuthEvent(null, emailKey, "LOGIN_FAILED", "FAILURE", clientIp, rawDeviceId);
                    }
                }
                throw new SecurityException("Credenciales inválidas");
            }
        }

        User user = optUser.get();
        String userEmailHmac = computeEmailHmac(user.getEmail());

        LocalDateTime now = LocalDateTime.now();
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(now)) {
            if (authAuditService != null) {
                authAuditService.recordAuthEvent(user, userEmailHmac, "LOGIN_FAILED", "BLOCKED", clientIp, rawDeviceId);
            }
            throw new SecurityException("Cuenta bloqueada temporalmente");
        }
        if (user.getLockedUntil() != null && !user.getLockedUntil().isAfter(now)) {
            user.setFailedLoginAttempts(0);
            user.setLockedUntil(null);
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            user.setFailedLoginAttempts(user.getFailedLoginAttempts() + 1);
            if (user.getFailedLoginAttempts() >= 5) {
                user.setLockedUntil(now.plusMinutes(15));
                userRepository.save(user);
                if (authAuditService != null) {
                    authAuditService.recordAuthEvent(user, userEmailHmac, "ACCOUNT_LOCKED", "BLOCKED", clientIp, rawDeviceId);
                }
            } else {
                userRepository.save(user);
                if (authAuditService != null) {
                    authAuditService.recordAuthEvent(user, userEmailHmac, "LOGIN_FAILED", "FAILURE", clientIp, rawDeviceId);
                }
            }
            throw new SecurityException("Credenciales inválidas");
        }

        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        if (authAuditService != null) {
            authAuditService.recordAuthEvent(user, userEmailHmac, "LOGIN_SUCCESS", "SUCCESS", clientIp, rawDeviceId);
        }

        return generateTokens(user);
    }

    private AuthResponse generateTokens(User user) {
        String role = (user.getRole() != null && !user.getRole().isBlank()) ? user.getRole() : "USER";
        String accessToken = jwtUtil.generateAccessToken(user.getId().toString(), role);
        String rawRefreshToken = UUID.randomUUID().toString() + "-" + UUID.randomUUID().toString();
        
        RefreshToken rToken = new RefreshToken();
        rToken.setTokenHash(sha256(rawRefreshToken));
        rToken.setUser(user);
        rToken.setExpiresAt(LocalDateTime.now().plusNanos(refreshTokenExpirationMs * 1_000_000));
        refreshTokenRepository.save(rToken);

        return new AuthResponse(accessToken, rawRefreshToken);
    }

    @Transactional
    public AuthResponse refresh(RefreshRequest request) {
        String tokenHash = sha256(request.getRefreshToken());
        Optional<RefreshToken> optToken = refreshTokenRepository.findByTokenHash(tokenHash);
        
        if (optToken.isEmpty()) {
            throw new SecurityException("Refresh token inválido");
        }

        RefreshToken refreshToken = optToken.get();
        User user = refreshToken.getUser();

        if (refreshToken.isUsed()) {
            // Reutilización detectada: revocar TODA la familia (todos los tokens del usuario)
            refreshTokenRepository.deleteByUser_Id(user.getId());
            throw new SecurityException("Reutilización de refresh token detectada. Sesión terminada.");
        }

        if (refreshToken.getExpiresAt().isBefore(LocalDateTime.now())) {
            refreshTokenRepository.delete(refreshToken);
            throw new SecurityException("Refresh token expirado");
        }

        // Marcar como usado
        refreshToken.setUsed(true);
        refreshTokenRepository.save(refreshToken);

        return generateTokens(user);
    }

    @Transactional
    public void logout(String accessToken, String refreshToken) {
        logout(accessToken, refreshToken, null, null);
    }

    @Transactional
    public void logout(String accessToken, String refreshToken, String clientIp, String rawDeviceId) {
        User user = null;
        if (accessToken != null) {
            try {
                String userIdStr = jwtUtil.getUserId(accessToken);
                if (userIdStr != null) {
                    user = userRepository.findById(UUID.fromString(userIdStr)).orElse(null);
                }
            } catch (Exception ignored) {}

            String jti = jwtUtil.getJti(accessToken);
            // 1. Escribir primero en el store activo (Redis / memoria con TTL)
            try {
                revocationStore.revoke(jti, java.time.Duration.ofMinutes(15));
            } catch (Exception e) {
                // Si falla store remoto, degradar y continuar a la base de datos
            }

            // 2. Persistir en la base de datos de manera idempotente
            RevokedToken rt = new RevokedToken();
            rt.setJti(jti);
            rt.setExpiresAt(LocalDateTime.now().plusDays(1)); // arbitrary short TTL since access tokens are short lived
            revokedTokenRepository.save(rt);
        }
        if (refreshToken != null) {
            String tokenHash = sha256(refreshToken);
            Optional<RefreshToken> rto = refreshTokenRepository.findByTokenHash(tokenHash);
            if (user == null && rto.isPresent()) {
                user = rto.get().getUser();
            }
            rto.ifPresent(refreshTokenRepository::delete);
        }

        if (user != null && authAuditService != null) {
            authAuditService.recordAuthEvent(user, computeEmailHmac(user.getEmail()), "LOGOUT", "SUCCESS", clientIp, rawDeviceId);
        }
    }

    @Transactional
    public AuthResponse changePassword(String userId, String currentPassword, String newPassword) {
        User user = userRepository.findById(UUID.fromString(userId))
                .orElseThrow(() -> new SecurityException("Usuario no encontrado"));
                
        if (!passwordEncoder.matches(currentPassword, user.getPasswordHash())) {
            throw new SecurityException("Contraseña actual incorrecta");
        }
        
        user.setPasswordHash(passwordEncoder.encode(newPassword));
        userRepository.save(user);
        
        // Revocar todos los tokens
        refreshTokenRepository.deleteByUser_Id(user.getId());
        
        // Generar nuevos tokens
        return generateTokens(user);
    }
}
