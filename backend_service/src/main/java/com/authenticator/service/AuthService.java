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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final RevokedTokenRepository revokedTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final long refreshTokenExpirationMs;
    private final String dummyHash;

    public AuthService(UserRepository userRepository, RefreshTokenRepository refreshTokenRepository,
                       RevokedTokenRepository revokedTokenRepository, PasswordEncoder passwordEncoder,
                       JwtUtil jwtUtil, @Value("${app.jwt.refresh-token-expiration-ms:604800000}") long refreshTokenExpirationMs) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.revokedTokenRepository = revokedTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.refreshTokenExpirationMs = refreshTokenExpirationMs;
        this.dummyHash = passwordEncoder.encode("dummy");
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
        userRepository.save(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        Optional<User> optUser = userRepository.findByEmail(request.getEmail());
        if (optUser.isEmpty()) {
            passwordEncoder.matches(request.getPassword(), dummyHash);
            throw new SecurityException("Credenciales inválidas");
        }

        User user = optUser.get();

        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now())) {
            throw new SecurityException("Cuenta bloqueada temporalmente");
        }

        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            user.setFailedLoginAttempts(user.getFailedLoginAttempts() + 1);
            if (user.getFailedLoginAttempts() >= 5) {
                user.setLockedUntil(LocalDateTime.now().plusMinutes(15));
            }
            userRepository.save(user);
            throw new SecurityException("Credenciales inválidas");
        }

        user.setFailedLoginAttempts(0);
        user.setLockedUntil(null);
        userRepository.save(user);

        return generateTokens(user);
    }

    private AuthResponse generateTokens(User user) {
        String accessToken = jwtUtil.generateAccessToken(user.getId().toString());
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
        if (accessToken != null) {
            String jti = jwtUtil.getJti(accessToken);
            RevokedToken rt = new RevokedToken();
            rt.setJti(jti);
            rt.setExpiresAt(LocalDateTime.now().plusDays(1)); // arbitrary short TTL since access tokens are short lived
            revokedTokenRepository.save(rt);
        }
        if (refreshToken != null) {
            String tokenHash = sha256(refreshToken);
            refreshTokenRepository.findByTokenHash(tokenHash).ifPresent(refreshTokenRepository::delete);
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
