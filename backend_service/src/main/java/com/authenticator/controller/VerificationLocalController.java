package com.authenticator.controller;

import com.authenticator.domain.RiskDecision;
import com.authenticator.domain.RiskScoreBreakdown;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.domain.VerificationResult;
import com.authenticator.domain.NetworkRiskAnalysis;
import com.authenticator.dto.LocalVerificationRequest;
import com.authenticator.repository.UserRepository;
import com.authenticator.service.BlockchainAuditService;
import com.authenticator.service.NetworkRiskService;
import com.authenticator.service.RiskEngineService;
import com.authenticator.service.VerificationSessionService;
import com.authenticator.service.BlacklistService;
import com.authenticator.util.IpResolver;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/verification")
public class VerificationLocalController {

    private final UserRepository userRepository;
    private final VerificationSessionService sessionService;
    private final NetworkRiskService networkRiskService;
    private final RiskEngineService riskEngineService;
    private final IpResolver ipResolver;
    private final BlockchainAuditService blockchainAuditService;
    private final BlacklistService blacklistService;
    private final org.springframework.core.env.Environment environment;

    public VerificationLocalController(
            UserRepository userRepository,
            VerificationSessionService sessionService,
            NetworkRiskService networkRiskService,
            RiskEngineService riskEngineService,
            IpResolver ipResolver,
            BlockchainAuditService blockchainAuditService,
            BlacklistService blacklistService,
            org.springframework.core.env.Environment environment) {
        this.userRepository = userRepository;
        this.sessionService = sessionService;
        this.networkRiskService = networkRiskService;
        this.riskEngineService = riskEngineService;
        this.ipResolver = ipResolver;
        this.blockchainAuditService = blockchainAuditService;
        this.blacklistService = blacklistService;
        this.environment = environment;
    }

    @PostMapping("/local-result")
    public ResponseEntity<?> informLocalResult(
            Authentication authentication,
            @Valid @RequestBody LocalVerificationRequest request,
            HttpServletRequest httpRequest) {
        if (authentication == null || authentication.getPrincipal() == null) {
            return ResponseEntity.status(401).build();
        }
        String userId = (String) authentication.getPrincipal();
        Optional<User> optUser = userRepository.findById(UUID.fromString(userId));
        if (optUser.isEmpty()) {
            return ResponseEntity.notFound().build();
        }
        User user = optUser.get();

        String clientIp = ipResolver.resolveClientIp(httpRequest);
        String maskedIp = maskIp(clientIp);

        // Identificador único de intento de validación para trazabilidad e idempotencia en Blockchain (Ajuste 2)
        String attemptId = (request.getAttemptId() != null && !request.getAttemptId().isBlank())
                ? request.getAttemptId()
                : UUID.randomUUID().toString();
        String sessionAttemptId = userId + ":" + attemptId;

        // CU-0033/CU-0034: Bloqueo duro unificado por integridad de dispositivo (Emulador o Root/Jailbreak)
        boolean deviceCompromised = Boolean.TRUE.equals(request.getEmulatorDetected())
                || Boolean.TRUE.equals(request.getDeviceCompromised());

        if (deviceCompromised) {
            VerificationResult devResult = new VerificationResult();
            devResult.setEmulatorDetected(Boolean.TRUE.equals(request.getEmulatorDetected()));
            devResult.setDeviceCompromised(Boolean.TRUE.equals(request.getDeviceCompromised()));
            devResult.setMatchType("REJECTED_DEVICE_COMPROMISED");
            RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(devResult);
            devResult.setCompositeRiskScore(breakdown.getCompositeScore());
            devResult.setRiskDecision(breakdown.getDecision());
            devResult.setRiskBreakdown(breakdown);
            sessionService.updateSessionStatus(userId, devResult);
            blockchainAuditService.queueRiskAssessment(sessionAttemptId, breakdown.getDecision(), breakdown.getCompositeScore(), breakdown, maskedIp, request.getDniHash());
            return ResponseEntity.status(403).body(java.util.Map.of(
                "errorCode", "EMULATOR_DETECTED",
                "message", "Operación rechazada: se detectó dispositivo comprometido o entorno emulado (CU-0033/CU-0034)",
                "decision", breakdown.getDecision().name(),
                "riskScore", breakdown.getCompositeScore()
            ));
        }

        // Mocks de prueba restringidos exclusivamente a perfiles dev/test (Ajuste 2)
        boolean isDevOrTest = environment != null && (
                java.util.Arrays.asList(environment.getActiveProfiles()).contains("dev") ||
                java.util.Arrays.asList(environment.getActiveProfiles()).contains("test")
        );

        if (isDevOrTest && "SPOOFING".equals(request.getDniHash())) {
            RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                    .compositeScore(100)
                    .decision(RiskDecision.BLOQUEAR)
                    .hardRuleApplied("SPOOFING_DETECTED")
                    .evaluatedAt(LocalDateTime.now())
                    .build();
            blockchainAuditService.queueRiskAssessment(sessionAttemptId, RiskDecision.BLOQUEAR, 100, breakdown, maskedIp, request.getDniHash());
            return ResponseEntity.status(403).body(java.util.Map.of("errorCode", "SPOOFING_DETECTED"));
        }
        if (isDevOrTest && "BLOCKED".equals(request.getDniHash())) {
            RiskScoreBreakdown breakdown = RiskScoreBreakdown.builder()
                    .compositeScore(100)
                    .decision(RiskDecision.BLOQUEAR)
                    .hardRuleApplied("DNI_BLOCKED_STOLEN")
                    .evaluatedAt(LocalDateTime.now())
                    .build();
            blockchainAuditService.queueRiskAssessment(sessionAttemptId, RiskDecision.BLOQUEAR, 100, breakdown, maskedIp, request.getDniHash());
            return ResponseEntity.status(403).body(java.util.Map.of("errorCode", "DNI_BLOCKED_STOLEN"));
        }

        // CU-0032: Evaluación y persistencia de riesgo de red en la sesión
        NetworkRiskAnalysis networkAnalysis = networkRiskService.evaluateNetworkRisk(
                clientIp,
                request.getClientVpnDetected(),
                request.getClientProxyDetected()
        );

        VerificationResult activeSession = sessionService.getSessionStatus(userId);
        if (activeSession == null) {
            activeSession = new VerificationResult();
        }
        activeSession.setEmulatorDetected(false);
        activeSession.setDeviceCompromised(false);
        activeSession.setNetworkRiskLevel(networkAnalysis.getRiskLevel());
        activeSession.setClientVpnDetected(Boolean.TRUE.equals(request.getClientVpnDetected()));
        activeSession.setClientProxyDetected(Boolean.TRUE.equals(request.getClientProxyDetected()));
        activeSession.setBehavioralAdultScore(request.getBehavioralAdultScore());
        activeSession.setLivenessScore(request.getLivenessScore());
        activeSession.setFaceMatchScore(request.getFaceMatchScore());
        activeSession.setIsLatestDocument(request.getIsLatestDocument());
        activeSession.setFailedFaceAttempts(request.getFailedFaceAttempts());

        // CU-0043: Verificación de lista negra de DNI
        if (request.getDniHash() != null && blacklistService.isDniBlacklisted(request.getDniHash())) {
            activeSession.setDniBlacklisted(true);
        }

        // CU-0045: Verificación de bloqueo temporal de usuario
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now())) {
            activeSession.setUserLockedOut(true);
        }

        // CU-0023: Evaluación de Riesgo Compuesto
        RiskScoreBreakdown breakdown = riskEngineService.evaluateRiskDetailed(activeSession);
        activeSession.setCompositeRiskScore(breakdown.getCompositeScore());
        activeSession.setRiskDecision(breakdown.getDecision());
        activeSession.setRiskBreakdown(breakdown);
        sessionService.updateSessionStatus(userId, activeSession);

        // CU-0030 / CU-0029: Registro de Auditoría en Blockchain off-chain enriquecido
        blockchainAuditService.queueRiskAssessment(sessionAttemptId, breakdown.getDecision(), breakdown.getCompositeScore(), breakdown, maskedIp, request.getDniHash());

        if (breakdown.getDecision() == RiskDecision.BLOQUEAR) {
            return ResponseEntity.status(403).body(java.util.Map.of(
                "errorCode", "RISK_BLOCKED",
                "decision", breakdown.getDecision().name(),
                "riskScore", breakdown.getCompositeScore(),
                "riskBreakdown", breakdown.toAuditMap()
            ));
        }

        if (breakdown.getDecision() == RiskDecision.REVISIÓN) {
            user.setStatus(UserStatus.PENDING_VERIFICATION);
            userRepository.save(user);
            return ResponseEntity.ok(java.util.Map.of(
                "status", "UNDER_REVIEW",
                "decision", breakdown.getDecision().name(),
                "riskScore", breakdown.getCompositeScore(),
                "riskBreakdown", breakdown.toAuditMap(),
                "networkRiskLevel", networkAnalysis.getRiskLevel().name()
            ));
        }

        // AUTORIZAR
        // This sets LOCALLY_VERIFIED only, ensuring VERIFIED is reserved for remote
        if (user.getStatus() == UserStatus.REGISTERED || user.getStatus() == UserStatus.PENDING_VERIFICATION) {
            user.setStatus(UserStatus.LOCALLY_VERIFIED);
            user.setDniHash(request.getDniHash());
            user.setVerifiedAt(LocalDateTime.now());
            try {
                userRepository.save(user);
            } catch (Exception e) {
                return ResponseEntity.badRequest().body("DNI hash might already be associated with another active account.");
            }
        }
        return ResponseEntity.ok(java.util.Map.of(
            "status", "OK",
            "decision", breakdown.getDecision().name(),
            "riskScore", breakdown.getCompositeScore(),
            "riskBreakdown", breakdown.toAuditMap(),
            "networkRiskLevel", networkAnalysis.getRiskLevel().name()
        ));
    }

    private String maskIp(String ip) {
        if (ip == null || ip.isBlank()) {
            return "0.0.***.***";
        }
        if (ip.contains(".")) {
            String[] parts = ip.split("\\.");
            if (parts.length >= 2) {
                return parts[0] + "." + parts[1] + ".***.***";
            }
        } else if (ip.contains(":")) {
            String[] parts = ip.split(":");
            if (parts.length >= 2) {
                return parts[0] + ":" + parts[1] + ":***:***";
            }
        }
        return "***.***";
    }
}
