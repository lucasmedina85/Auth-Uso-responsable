package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.dto.SecurityFactorDTO;
import com.authenticator.dto.SecurityScoreResponse;
import com.authenticator.repository.BlockchainAuditLogRepository;
import com.authenticator.repository.TrustedDeviceRepository;
import com.authenticator.repository.UserRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class SecurityScoreService {

    private final UserRepository userRepository;
    private final TrustedDeviceRepository deviceRepository;
    private final BlockchainAuditLogRepository auditLogRepository;

    @Value("${app.security-score.base-score:15}")
    private int baseScore;

    @Value("${app.security-score.unverified-max-score:55}")
    private int unverifiedMaxScore;

    @Value("${app.security-score.failed-attempts-window-hours:24}")
    private int failedAttemptsWindowHours;

    @Value("${app.security-score.levels.alto-min:75}")
    private int altoMin;

    @Value("${app.security-score.levels.medio-min:45}")
    private int medioMin;

    public SecurityScoreService(UserRepository userRepository,
                                TrustedDeviceRepository deviceRepository,
                                BlockchainAuditLogRepository auditLogRepository) {
        this.userRepository = userRepository;
        this.deviceRepository = deviceRepository;
        this.auditLogRepository = auditLogRepository;
    }

    /**
     * Calcula el Security Score multifactorial del usuario.
     * Señales de cliente (hasBiometrics, hasScreenLock) son de baja confianza y tienen peso mínimo.
     * Reutiliza la última decisión del motor de riesgo persistida en blockchain_audit_logs.
     */
    @Transactional(readOnly = true)
    public SecurityScoreResponse calculateScore(UUID userId, boolean hasBiometrics, boolean hasScreenLock) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("Usuario no encontrado"));

        List<SecurityFactorDTO> factors = new ArrayList<>();
        int runningScore = baseScore;

        // 1. Identidad Verificada (oficial) - Tope: +30
        boolean isIdentityVerified = (user.getStatus() == UserStatus.LOCALLY_VERIFIED || user.getStatus() == UserStatus.VERIFIED);
        if (isIdentityVerified) {
            runningScore += 30;
            factors.add(SecurityFactorDTO.builder()
                    .name("Identidad Verificada")
                    .description("Validación biométrica y documental completada oficialmente")
                    .contribution(30)
                    .status("POSITIVE")
                    .build());
        } else {
            factors.add(SecurityFactorDTO.builder()
                    .name("Identidad Verificada")
                    .description("Pendiente de validación de identidad")
                    .contribution(0)
                    .status("NEUTRAL")
                    .build());
        }

        // 2. Última Evaluación de Riesgo Persistida - Tope: +20 / -30
        if (user.getDniHash() != null) {
            Optional<BlockchainAuditLog> latestLog = auditLogRepository.findFirstByDniHashOrderByCreatedAtDesc(user.getDniHash());
            if (latestLog.isPresent()) {
                String decision = latestLog.get().getDecision();
                if (RiskDecision.AUTORIZAR.name().equalsIgnoreCase(decision)) {
                    runningScore += 20;
                    factors.add(SecurityFactorDTO.builder()
                            .name("Evaluación de Seguridad Operacional")
                            .description("Última evaluación sin anomalías ni sospechas")
                            .contribution(20)
                            .status("POSITIVE")
                            .build());
                } else if (RiskDecision.REVISIÓN.name().equalsIgnoreCase(decision) || "REVISION".equalsIgnoreCase(decision)) {
                    runningScore += 5;
                    factors.add(SecurityFactorDTO.builder()
                            .name("Evaluación de Seguridad Operacional")
                            .description("Última evaluación sugiere comprobaciones adicionales")
                            .contribution(5)
                            .status("NEUTRAL")
                            .build());
                } else if (RiskDecision.BLOQUEAR.name().equalsIgnoreCase(decision)) {
                    runningScore -= 30;
                    factors.add(SecurityFactorDTO.builder()
                            .name("Evaluación de Seguridad Operacional")
                            .description("Alerta preventiva de riesgo registrada recientemente")
                            .contribution(-30)
                            .status("NEGATIVE")
                            .build());
                }
            } else {
                factors.add(SecurityFactorDTO.builder()
                        .name("Evaluación de Seguridad Operacional")
                        .description("Sin evaluaciones de riesgo previas")
                        .contribution(0)
                        .status("NEUTRAL")
                        .build());
            }
        } else {
            factors.add(SecurityFactorDTO.builder()
                    .name("Evaluación de Seguridad Operacional")
                    .description("Sin documento registrado para evaluación")
                    .contribution(0)
                    .status("NEUTRAL")
                    .build());
        }

        // 3. Dispositivos de Confianza - Tope: +20
        long trustedCount = deviceRepository.countByUserIdAndStatus(userId, TrustedDeviceStatus.TRUSTED);
        if (trustedCount > 0) {
            runningScore += 20;
            factors.add(SecurityFactorDTO.builder()
                    .name("Dispositivos de Confianza")
                    .description("Dispositivo habitual reconocido y aprobado (" + trustedCount + " activo)")
                    .contribution(20)
                    .status("POSITIVE")
                    .build());
        } else {
            long pendingCount = deviceRepository.countByUserIdAndStatus(userId, TrustedDeviceStatus.PENDING);
            if (pendingCount > 0) {
                runningScore += 5;
                factors.add(SecurityFactorDTO.builder()
                        .name("Dispositivos de Confianza")
                        .description("Dispositivo pendiente de confirmación")
                        .contribution(5)
                        .status("NEUTRAL")
                        .build());
            } else {
                factors.add(SecurityFactorDTO.builder()
                        .name("Dispositivos de Confianza")
                        .description("Sin dispositivos de confianza vinculados")
                        .contribution(0)
                        .status("NEUTRAL")
                        .build());
            }
        }

        // 4. Antigüedad y Estabilidad de la Cuenta - Tope: +10
        LocalDateTime createdAt = user.getCreatedAt() != null ? user.getCreatedAt() : LocalDateTime.now();
        long daysActive = Duration.between(createdAt, LocalDateTime.now()).toDays();
        if (daysActive >= 30) {
            runningScore += 10;
            factors.add(SecurityFactorDTO.builder()
                    .name("Antigüedad de la Cuenta")
                    .description("Historial de cuenta consolidado (> 30 días)")
                    .contribution(10)
                    .status("POSITIVE")
                    .build());
        } else if (daysActive >= 7) {
            runningScore += 5;
            factors.add(SecurityFactorDTO.builder()
                    .name("Antigüedad de la Cuenta")
                    .description("Cuenta en período inicial de uso (> 7 días)")
                    .contribution(5)
                    .status("POSITIVE")
                    .build());
        } else {
            factors.add(SecurityFactorDTO.builder()
                    .name("Antigüedad de la Cuenta")
                    .description("Cuenta de reciente creación")
                    .contribution(0)
                    .status("NEUTRAL")
                    .build());
        }

        // 5. Señales del Dispositivo reportadas por Cliente (Baja confianza) - Tope: +5
        if (hasBiometrics || hasScreenLock) {
            runningScore += 5;
            factors.add(SecurityFactorDTO.builder()
                    .name("Protección Local del Dispositivo")
                    .description("Bloqueo de pantalla o biometría local configurada")
                    .contribution(5)
                    .status("POSITIVE")
                    .build());
        } else {
            factors.add(SecurityFactorDTO.builder()
                    .name("Protección Local del Dispositivo")
                    .description("Sin mecanismos de bloqueo local declarados")
                    .contribution(0)
                    .status("NEUTRAL")
                    .build());
        }

        // 6. Intentos Fallidos de Inicio de Sesión (en ventana temporal) - Deducción: hasta -20
        LocalDateTime updatedAt = user.getUpdatedAt() != null ? user.getUpdatedAt() : LocalDateTime.now();
        LocalDateTime windowStart = LocalDateTime.now().minusHours(failedAttemptsWindowHours);
        if (user.getFailedLoginAttempts() > 0 && updatedAt.isAfter(windowStart)) {
            int penalty = Math.min(user.getFailedLoginAttempts() * 5, 20);
            runningScore -= penalty;
            factors.add(SecurityFactorDTO.builder()
                    .name("Historial de Acceso Reciente")
                    .description("Intentos fallidos de contraseña detectados en las últimas " + failedAttemptsWindowHours + " h")
                    .contribution(-penalty)
                    .status("NEGATIVE")
                    .build());
        } else {
            factors.add(SecurityFactorDTO.builder()
                    .name("Historial de Acceso Reciente")
                    .description("Accesos limpios sin incidencias recientes")
                    .contribution(0)
                    .status("POSITIVE")
                    .build());
        }

        // Clamping a [0, 100]
        int finalScore = Math.max(0, Math.min(100, runningScore));

        // Regla: Usuario sin identidad verificada NUNCA llega a "Alta confianza" (tope configurable)
        if (!isIdentityVerified && finalScore > unverifiedMaxScore) {
            finalScore = unverifiedMaxScore;
        }

        // Nivel según umbrales configurables
        String level;
        String levelDescription;
        if (finalScore >= altoMin) {
            level = "ALTO";
            levelDescription = "Alta Confianza";
        } else if (finalScore >= medioMin) {
            level = "MEDIO";
            levelDescription = "Confianza Media";
        } else {
            level = "BAJO";
            levelDescription = "Atención Requerida";
        }

        return SecurityScoreResponse.builder()
                .score(finalScore)
                .level(level)
                .levelDescription(levelDescription)
                .factors(factors)
                .build();
    }
}
