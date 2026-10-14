package com.authenticator.service;

import com.authenticator.domain.*;
import com.authenticator.dto.*;
import com.authenticator.exception.*;
import com.authenticator.repository.*;
import com.authenticator.security.ExportSigningKeyManager;
import com.authenticator.security.RsaKeyManager;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.security.Signature;
import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.core.env.Environment;

@Service
public class OAuthService {

    private static final Logger log = LoggerFactory.getLogger(OAuthService.class);

    private final OAuthClientRepository clientRepository;
    private final OAuthAuthorizationCodeRepository codeRepository;
    private final OAuthIssuedTokenRepository tokenRepository;
    private final LinkedApplicationRepository linkedAppRepository;
    private final OAuthAuditLogRepository auditLogRepository;
    private final RsaKeyManager rsaKeyManager;
    private final ExportSigningKeyManager exportSigningKeyManager;
    private final VerificationSessionService sessionService;
    private final OAuthRateLimitingService rateLimitingService;
    private final BlacklistService blacklistService;
    private final com.authenticator.security.RevocationStore revocationStore;
    private final PasswordEncoder clientPasswordEncoder = new BCryptPasswordEncoder();
    private final SecureRandom secureRandom = new SecureRandom();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${app.oauth.pairwise-secret:${OAUTH_PAIRWISE_SECRET:}}")
    private String pairwiseSecret;

    @Value("${app.oauth.audit-secret:${app.oauth.pairwise-secret:${OAUTH_AUDIT_SECRET:}}}")
    private String auditSecret;

    @Value("${app.oauth.issuer:https://auth.example.com}")
    private String issuer;

    @Value("${app.oauth.access-token-expiration-ms:300000}")
    private long accessTokenExpirationMs;

    @Value("${app.oauth.authorization-code-expiration-ms:60000}")
    private long codeExpirationMs;

    @Value("${app.oauth.risk-decision-max-age-minutes:60}")
    private long riskDecisionMaxAgeMinutes;

    @Value("${app.export.max-range-days:90}")
    private int maxRangeDays = 90;

    @Value("${app.export.max-records:500}")
    private int maxRecords = 500;

    @Autowired(required = false)
    private Environment environment;

    @PostConstruct
    public void validateSecrets() {
        if (environment != null && Arrays.asList(environment.getActiveProfiles()).contains("prod")) {
            if (pairwiseSecret == null || pairwiseSecret.isBlank() || pairwiseSecret.contains("dev-dummy") || pairwiseSecret.contains("test-only")) {
                throw new IllegalStateException("OAUTH_PAIRWISE_SECRET es obligatorio en el perfil 'prod' y no puede estar vacío ni usar valores por defecto");
            }
        }
    }

    public OAuthService(OAuthClientRepository clientRepository,
                        OAuthAuthorizationCodeRepository codeRepository,
                        OAuthIssuedTokenRepository tokenRepository,
                        LinkedApplicationRepository linkedAppRepository,
                        OAuthAuditLogRepository auditLogRepository,
                        RsaKeyManager rsaKeyManager,
                        VerificationSessionService sessionService,
                        OAuthRateLimitingService rateLimitingService,
                        BlacklistService blacklistService,
                        com.authenticator.security.RevocationStore revocationStore,
                        ExportSigningKeyManager exportSigningKeyManager) {
        this.clientRepository = clientRepository;
        this.codeRepository = codeRepository;
        this.tokenRepository = tokenRepository;
        this.linkedAppRepository = linkedAppRepository;
        this.auditLogRepository = auditLogRepository;
        this.rsaKeyManager = rsaKeyManager;
        this.sessionService = sessionService;
        this.rateLimitingService = rateLimitingService;
        this.blacklistService = blacklistService;
        this.revocationStore = revocationStore;
        this.exportSigningKeyManager = exportSigningKeyManager;
    }

    public ClientInfoResponse getClientInfo(String clientId, String redirectUri) {
        OAuthClient client = clientRepository.findByClientIdAndStatus(clientId, "ACTIVE")
                .orElseThrow(() -> new OAuthException("invalid_client", "Cliente OAuth no registrado o inactivo"));

        if (!client.getRedirectUris().contains(redirectUri)) {
            throw new OAuthException("invalid_request", "La redirect_uri solicitada no coincide con los registros autorizados");
        }

        Set<String> scopes = new HashSet<>(Arrays.asList(client.getAllowedScopes().split(",")));
        return ClientInfoResponse.builder()
                .clientId(client.getClientId())
                .clientName(client.getName())
                .redirectUri(redirectUri)
                .allowedScopes(scopes)
                .build();
    }

    @Transactional
    public TokenExchangeResponse processTokenExchange(User user, TokenExchangeRequest request, String clientIp) {
        if (!rateLimitingService.checkRequestRateLimit(clientIp)) {
            throw new OAuthException("slow_down", "Demasiadas solicitudes. Intente más tarde.");
        }

        if (request.getConsentGiven() == null || !request.getConsentGiven()) {
            throw new OAuthException("consent_required", "Se requiere el consentimiento explícito del usuario.");
        }

        // Validación anti-phishing estricta de cliente y redirect_uri
        OAuthClient client = clientRepository.findByClientIdAndStatus(request.getClientId(), "ACTIVE")
                .orElseThrow(() -> new OAuthException("invalid_client", "Cliente OAuth no registrado o inactivo"));

        if (!client.getRedirectUris().contains(request.getRedirectUri())) {
            throw new OAuthException("invalid_request", "redirect_uri no autorizada para este cliente");
        }

        // Validación de scopes
        Set<String> allowedScopes = new HashSet<>(Arrays.asList(client.getAllowedScopes().split(",")));
        String[] requestedScopes = request.getScope().split("\\s+");
        for (String reqScope : requestedScopes) {
            if (!reqScope.isBlank() && !allowedScopes.contains(reqScope)) {
                throw new OAuthException("invalid_scope", "Scope no permitido: " + reqScope);
            }
        }

        // Validación de PKCE
        if (!"S256".equalsIgnoreCase(request.getCodeChallengeMethod())) {
            throw new OAuthException("invalid_request", "Método code_challenge_method no soportado. Debe ser S256");
        }
        String challenge = request.getCodeChallenge();
        if (challenge == null || challenge.length() < 43 || challenge.length() > 128) {
            throw new OAuthException("invalid_request", "code_challenge inválido para S256");
        }

        // Validación de la condición del usuario y vigencia de la decisión AUTORIZAR
        if (user.getLockedUntil() != null && user.getLockedUntil().isAfter(LocalDateTime.now())) {
            throw new OAuthRiskNotAuthorizedException("Usuario bloqueado temporalmente por seguridad hasta: " + user.getLockedUntil());
        }

        if (user.getDniHash() != null && blacklistService.isDniBlacklisted(user.getDniHash())) {
            throw new OAuthRiskNotAuthorizedException("DNI bloqueado por lista negra de fraude (CU-0043)");
        }

        if (user.getStatus() != UserStatus.LOCALLY_VERIFIED && user.getStatus() != UserStatus.VERIFIED) {
            throw new OAuthRiskNotAuthorizedException("El usuario no cuenta con una validación de identidad completada.");
        }

        VerificationResult activeSession = sessionService.getSessionStatus(user.getId().toString());
        if (activeSession != null && activeSession.getRiskDecision() != null && activeSession.getRiskDecision() != RiskDecision.AUTORIZAR) {
            throw new OAuthRiskNotAuthorizedException("La última evaluación de riesgo no resultó en AUTORIZAR (decisión: " + activeSession.getRiskDecision() + ")");
        }

        if (user.getVerifiedAt() != null) {
            long minutesSinceVerification = Duration.between(user.getVerifiedAt(), LocalDateTime.now()).toMinutes();
            if (minutesSinceVerification > riskDecisionMaxAgeMinutes) {
                throw new OAuthRiskNotAuthorizedException("La validación de riesgo del usuario superó la ventana de vigencia permitida (" + riskDecisionMaxAgeMinutes + " min).");
            }
        }

        // Generar authorization code aleatorio seguro (32 bytes = 256 bits)
        byte[] codeBytes = new byte[32];
        secureRandom.nextBytes(codeBytes);
        String code = Base64.getUrlEncoder().withoutPadding().encodeToString(codeBytes);
        String codeHash = sha256Hex(code);

        OAuthAuthorizationCode authCode = new OAuthAuthorizationCode();
        authCode.setCodeHash(codeHash);
        authCode.setClientId(client.getClientId());
        authCode.setUserId(user.getId());
        authCode.setRedirectUri(request.getRedirectUri());
        authCode.setCodeChallenge(request.getCodeChallenge());
        authCode.setCodeChallengeMethod("S256");
        authCode.setNonce(request.getNonce());
        authCode.setScope(request.getScope());
        authCode.setExpiresAt(LocalDateTime.now().plusNanos(codeExpirationMs * 1_000_000));
        authCode.setUsed(false);

        codeRepository.save(authCode);

        // Registro de auditoría
        OAuthAuditLog auditLog = new OAuthAuditLog();
        auditLog.setEventType("TOKEN_EXCHANGE");
        auditLog.setClientId(client.getClientId());
        auditLog.setUserIdHash(hmacSha256(user.getId().toString(), auditSecret));
        auditLog.setDetails("Authorization code emitido con S256 PKCE");
        auditLogRepository.save(auditLog);

        return TokenExchangeResponse.builder()
                .code(code)
                .state(request.getState())
                .redirectUri(request.getRedirectUri())
                .build();
    }

    @Transactional
    public OAuthTokenResponse exchangeToken(String authHeader,
                                            String clientIdParam,
                                            String clientSecretParam,
                                            OAuthTokenRequest request,
                                            String clientIp) {
        if (!rateLimitingService.checkRequestRateLimit(clientIp)) {
            throw new OAuthException("slow_down", "Demasiadas solicitudes en /oauth/token. Intente más tarde.");
        }

        OAuthClient client = authenticateClient(authHeader, clientIdParam, clientSecretParam);
        String clientId = client.getClientId();

        // Validación del grant_type
        if (!"authorization_code".equals(request.getGrantType())) {
            throw new OAuthException("unsupported_grant_type", "grant_type debe ser 'authorization_code'");
        }

        if (request.getCode() == null || request.getCode().isBlank()) {
            throw new OAuthInvalidGrantException("code es requerido");
        }

        String codeHash = sha256Hex(request.getCode());
        OAuthAuthorizationCode authCode = codeRepository.findByCodeHash(codeHash)
                .orElseThrow(() -> new OAuthInvalidGrantException("Código de autorización inexistente"));

        // Detección de reúso de código
        if (authCode.isUsed()) {
            List<OAuthIssuedToken> previouslyIssued = tokenRepository.findByCodeHash(codeHash);
            for (OAuthIssuedToken tok : previouslyIssued) {
                tok.setStatus("REVOKED");
                tok.setRevokedAt(LocalDateTime.now());
                tokenRepository.save(tok);
            }

            OAuthAuditLog audit = new OAuthAuditLog();
            audit.setEventType("CODE_REUSE_DETECTED");
            audit.setClientId(clientId);
            audit.setUserIdHash(hmacSha256(authCode.getUserId().toString(), auditSecret));
            audit.setDetails("Reintento de uso de authorization code. Todos los tokens asociados fueron revocados.");
            auditLogRepository.save(audit);

            throw new OAuthInvalidGrantException("El código de autorización ya fue utilizado. Todos los tokens derivados han sido revocados.");
        }

        // Expiración
        if (LocalDateTime.now().isAfter(authCode.getExpiresAt())) {
            throw new OAuthInvalidGrantException("El código de autorización ha expirado");
        }

        // Cliente y redirect_uri
        if (!authCode.getClientId().equals(clientId)) {
            throw new OAuthInvalidGrantException("El código no pertenece al cliente solicitante");
        }
        if (!authCode.getRedirectUri().equals(request.getRedirectUri())) {
            throw new OAuthInvalidGrantException("redirect_uri no coincide con la original del código");
        }

        // Verificación PKCE estricta (S256)
        String verifier = request.getCodeVerifier();
        if (verifier == null || verifier.length() < 43 || verifier.length() > 128) {
            throw new OAuthInvalidGrantException("code_verifier inválido para PKCE S256");
        }

        String computedChallenge = computeS256Challenge(verifier);
        if (!MessageDigest.isEqual(computedChallenge.getBytes(StandardCharsets.UTF_8), authCode.getCodeChallenge().getBytes(StandardCharsets.UTF_8))) {
            throw new OAuthInvalidGrantException("Fallo en la validación de PKCE code_verifier");
        }

        // Marcar código como usado
        authCode.setUsed(true);
        authCode.setUsedAt(LocalDateTime.now());
        codeRepository.save(authCode);

        // Sub seudónimo pairwise único por cliente: HMAC-SHA256(userId, pairwiseSecret:clientId)
        String pairwiseKey = pairwiseSecret + ":" + clientId;
        String pseudonymSubject = hmacSha256(authCode.getUserId().toString(), pairwiseKey);

        // Generar JWT RS256 con claims mínimos y cero PII
        String jti = UUID.randomUUID().toString();
        Map<String, Object> extraClaims = new LinkedHashMap<>();
        extraClaims.put("scope", authCode.getScope());
        if (authCode.getNonce() != null) {
            extraClaims.put("nonce", authCode.getNonce());
        }
        extraClaims.put("age_verified", true);
        extraClaims.put("assurance_level", "HIGH");

        String jwt = rsaKeyManager.signToken(pseudonymSubject, clientId, issuer, jti, extraClaims, accessTokenExpirationMs);

        // Registrar token emitido
        OAuthIssuedToken issuedToken = new OAuthIssuedToken();
        issuedToken.setTokenIdHash(sha256Hex(jti));
        issuedToken.setJti(jti);
        issuedToken.setCodeHash(codeHash);
        issuedToken.setClientId(clientId);
        issuedToken.setUserId(authCode.getUserId());
        issuedToken.setExpiresAt(LocalDateTime.now().plusNanos(accessTokenExpirationMs * 1_000_000));
        issuedToken.setStatus("ACTIVE");
        tokenRepository.save(issuedToken);

        // Actualizar linked_applications
        LinkedApplication linkedApp = linkedAppRepository.findByUserIdAndClientId(authCode.getUserId(), clientId)
                .orElseGet(() -> {
                    LinkedApplication app = new LinkedApplication();
                    app.setUserId(authCode.getUserId());
                    app.setClientId(clientId);
                    app.setLinkedAt(LocalDateTime.now());
                    return app;
                });
        linkedApp.setLastUsedAt(LocalDateTime.now());
        linkedApp.setStatus("ACTIVE");
        linkedApp.setScopes(authCode.getScope());
        linkedAppRepository.save(linkedApp);

        // Registro de auditoría
        OAuthAuditLog audit = new OAuthAuditLog();
        audit.setEventType("TOKEN_ISSUED");
        audit.setClientId(clientId);
        audit.setUserIdHash(hmacSha256(authCode.getUserId().toString(), auditSecret));
        audit.setDetails("Token JWT RS256 emitido exitosamente");
        auditLogRepository.save(audit);

        return OAuthTokenResponse.builder()
                .accessToken(jwt)
                .tokenType("Bearer")
                .expiresIn(accessTokenExpirationMs / 1000)
                .scope(authCode.getScope())
                .build();
    }

    public OAuthClient authenticateClient(String authHeader, String clientIdParam, String clientSecretParam) {
        String clientId;
        String clientSecret;

        if (authHeader != null && authHeader.toLowerCase().startsWith("basic ")) {
            String base64Creds = authHeader.substring(6).trim();
            try {
                byte[] decoded = Base64.getDecoder().decode(base64Creds);
                String creds = new String(decoded, StandardCharsets.UTF_8);
                int colon = creds.indexOf(':');
                if (colon == -1) {
                    throw new OAuthAuthenticationException("Credenciales Basic Auth inválidas");
                }
                clientId = creds.substring(0, colon);
                clientSecret = creds.substring(colon + 1);
            } catch (IllegalArgumentException e) {
                throw new OAuthAuthenticationException("Cabecera Basic Auth malformada");
            }
        } else if (clientIdParam != null && clientSecretParam != null) {
            clientId = clientIdParam;
            clientSecret = clientSecretParam;
        } else {
            throw new OAuthAuthenticationException("client_secret_basic requerido: se debe autenticar el cliente OAuth");
        }

        if (rateLimitingService.isClientLocked(clientId)) {
            long remaining = rateLimitingService.getRemainingLockoutSeconds(clientId);
            throw new OAuthClientLockedException("Cliente bloqueado temporalmente por reiterados intentos fallidos. Reintente en " + remaining + " segundos.", remaining);
        }

        OAuthClient client = clientRepository.findByClientIdAndStatus(clientId, "ACTIVE")
                .orElseGet(() -> {
                    rateLimitingService.recordClientSecretFailure(clientId);
                    throw new OAuthAuthenticationException("Cliente no registrado o inactivo");
                });

        if (!clientPasswordEncoder.matches(clientSecret, client.getClientSecretHash())) {
            rateLimitingService.recordClientSecretFailure(clientId);
            throw new OAuthAuthenticationException("Credenciales de cliente inválidas");
        }

        rateLimitingService.recordClientSecretSuccess(clientId);
        return client;
    }

    /**
     * Introspección de tokens OAuth 2.0 (RFC 7662).
     * Exige autenticación de cliente (mismo esquema y rate limiting que /token).
     * Solo permite introspeccionar tokens con aud == client_id.
     */
    public Map<String, Object> introspectToken(String token, String clientIp) {
        return introspectToken(null, null, null, token, clientIp);
    }

    public Map<String, Object> introspectToken(String authHeader,
                                              String clientIdParam,
                                              String clientSecretParam,
                                              String token,
                                              String clientIp) {
        if (!rateLimitingService.checkRequestRateLimit(clientIp)) {
            throw new OAuthException("slow_down", "Demasiadas solicitudes en /oauth/introspect. Intente más tarde.");
        }

        OAuthClient authenticatedClient = authenticateClient(authHeader, clientIdParam, clientSecretParam);

        if (token == null || token.isBlank()) {
            return Map.of("active", false);
        }

        io.jsonwebtoken.Claims claims;
        try {
            claims = rsaKeyManager.validateAndParseToken(token);
        } catch (Exception e) {
            log.debug("Fallo validación criptográfica del token en introspección: {}", e.getMessage());
            return Map.of("active", false);
        }

        // RFC 7662: El cliente autenticado solo debe poder introspectar tokens emitidos para él (aud == client_id)
        if (claims.getAudience() == null || !claims.getAudience().contains(authenticatedClient.getClientId())) {
            log.debug("Token introspectado no pertenece al cliente solicitante. Retornando active: false sin filtrar metadatos.");
            return Map.of("active", false);
        }

        String jti = claims.getId();
        if (jti == null) {
            return Map.of("active", false);
        }

        // 1. Consultar RevocationStore activo (Redis / memoria)
        boolean isRevokedInStore = false;
        boolean storeFailed = false;
        try {
            isRevokedInStore = revocationStore.isRevoked(jti);
        } catch (Exception e) {
            storeFailed = true;
            log.warn("RevocationStore inaccesible al introspectar token (jti {}): {}. Modo degradado: verificando en base de datos.", jti, e.getMessage());
        }

        if (!storeFailed && isRevokedInStore) {
            return Map.of("active", false);
        }

        // 2. Consultar Base de Datos (oauth_issued_tokens) como fuente de verdad
        try {
            Optional<OAuthIssuedToken> issuedTokenOpt = tokenRepository.findByJti(jti);
            if (issuedTokenOpt.isEmpty()) {
                issuedTokenOpt = tokenRepository.findByTokenIdHash(sha256Hex(jti));
            }

            if (issuedTokenOpt.isPresent()) {
                OAuthIssuedToken issued = issuedTokenOpt.get();
                if (!"ACTIVE".equalsIgnoreCase(issued.getStatus()) || issued.getRevokedAt() != null) {
                    return Map.of("active", false);
                }
                if (issued.getExpiresAt().isBefore(LocalDateTime.now())) {
                    return Map.of("active", false);
                }
            } else {
                return Map.of("active", false);
            }
        } catch (Exception e) {
            log.error("Error al consultar base de datos durante introspección de token {}: {}", jti, e.getMessage());
            if (storeFailed) {
                log.error("Fallo simultáneo de RevocationStore y base de datos. Aplicando fail-closed (active=false).");
                return Map.of("active", false);
            }
            return Map.of("active", false);
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("active", true);
        result.put("sub", claims.getSubject());
        result.put("client_id", claims.getAudience() != null && !claims.getAudience().isEmpty() ? claims.getAudience().iterator().next() : null);
        result.put("exp", claims.getExpiration() != null ? claims.getExpiration().getTime() / 1000 : null);
        result.put("scope", claims.get("scope"));
        result.put("iss", claims.getIssuer());
        result.put("age_verified", claims.get("age_verified"));
        result.put("assurance_level", claims.get("assurance_level"));
        return result;
    }

    private String computeS256Challenge(String verifier) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(verifier.getBytes(StandardCharsets.US_ASCII));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (Exception e) {
            throw new RuntimeException("Error computing SHA-256 PKCE", e);
        }
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
            throw new RuntimeException("Error computing SHA-256", e);
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
            throw new RuntimeException("Error computing HMAC-SHA256", e);
        }
    }

    @Transactional(readOnly = true)
    public List<LinkedAppResponse> getLinkedApplications(UUID userId) {
        List<LinkedApplication> linkedApps = linkedAppRepository.findByUserIdOrderByLastUsedAtDesc(userId);
        List<LinkedAppResponse> result = new ArrayList<>();
        LocalDateTime now = LocalDateTime.now();

        for (LinkedApplication app : linkedApps) {
            String clientName = clientRepository.findById(app.getClientId())
                    .map(OAuthClient::getName)
                    .orElse(app.getClientId());

            List<OAuthIssuedToken> tokens = tokenRepository.findByUserIdAndClientIdOrderByCreatedAtDesc(userId, app.getClientId());
            String tokenStatus = "REVOCADO";
            if ("REVOKED".equalsIgnoreCase(app.getStatus())) {
                tokenStatus = "REVOCADO";
            } else if (!tokens.isEmpty()) {
                OAuthIssuedToken latest = tokens.get(0);
                if ("REVOKED".equalsIgnoreCase(latest.getStatus()) || latest.getRevokedAt() != null) {
                    tokenStatus = "REVOCADO";
                } else if (latest.getExpiresAt().isBefore(now)) {
                    tokenStatus = "VENCIDO";
                } else {
                    tokenStatus = "VIGENTE";
                }
            } else if ("ACTIVE".equalsIgnoreCase(app.getStatus())) {
                tokenStatus = "VIGENTE";
            }

            result.add(LinkedAppResponse.builder()
                    .id(app.getId())
                    .clientId(app.getClientId())
                    .appName(clientName)
                    .linkedAt(app.getLinkedAt())
                    .lastUsedAt(app.getLastUsedAt())
                    .status(app.getStatus())
                    .tokenStatus(tokenStatus)
                    .scopes(app.getScopes())
                    .build());
        }
        return result;
    }

    @Transactional
    public void unlinkApplication(UUID userId, String clientId) {
        LinkedApplication linkedApp = linkedAppRepository.findByUserIdAndClientId(userId, clientId)
                .orElseThrow(() -> new OAuthException("not_found", "Aplicación vinculada no encontrada"));

        linkedApp.setStatus("REVOKED");
        linkedApp.setUpdatedAt(LocalDateTime.now());
        linkedAppRepository.save(linkedApp);

        // Revocar todos los tokens emitidos para este usuario y cliente
        List<OAuthIssuedToken> tokens = tokenRepository.findByUserIdAndClientIdOrderByCreatedAtDesc(userId, clientId);
        LocalDateTime now = LocalDateTime.now();
        for (OAuthIssuedToken token : tokens) {
            token.setStatus("REVOKED");
            token.setRevokedAt(now);
            tokenRepository.save(token);

            if (token.getJti() != null) {
                try {
                    long remainingTtl = Duration.between(now, token.getExpiresAt()).getSeconds();
                    if (remainingTtl > 0) {
                        revocationStore.revoke(token.getJti(), Duration.ofSeconds(remainingTtl));
                    }
                } catch (Exception e) {
                    log.warn("Error revocando JTI en revocationStore al desvincular app: {}", e.getMessage());
                }
            }
        }

        // Registrar en oauth_audit_logs
        OAuthAuditLog audit = new OAuthAuditLog();
        audit.setEventType("APP_UNLINKED");
        audit.setClientId(clientId);
        audit.setUserIdHash(hmacSha256(userId.toString(), auditSecret));
        audit.setDetails("Aplicación OAuth desvinculada por el usuario. Tokens revocados activamente.");
        auditLogRepository.save(audit);
    }

    @Transactional
    public Map<String, Object> exportLinkedApplicationsLog(UUID userId) {
        return exportLinkedApplicationsLog(userId, null, null);
    }

    @Transactional
    public Map<String, Object> exportLinkedApplicationsLog(UUID userId, LocalDate startDate, LocalDate endDate) {
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

        String userHash = hmacSha256(userId.toString(), auditSecret);
        List<OAuthAuditLog> logs = auditLogRepository.findByUserIdHashOrderByCreatedAtDesc(userHash).stream()
                .filter(l -> !l.getCreatedAt().toLocalDate().isBefore(finalStart))
                .filter(l -> !l.getCreatedAt().toLocalDate().isAfter(finalEnd))
                .collect(Collectors.toList());

        int totalMatching = logs.size();
        boolean truncated = false;
        if (totalMatching > maxRecords) {
            truncated = true;
            logs = logs.subList(0, maxRecords);
        }

        List<Map<String, Object>> records = new ArrayList<>();
        for (OAuthAuditLog l : logs) {
            Map<String, Object> r = new LinkedHashMap<>();
            r.put("id", l.getId().toString());
            r.put("timestamp", l.getCreatedAt().toString());
            r.put("eventType", l.getEventType());
            r.put("clientId", l.getClientId());
            r.put("details", l.getDetails());
            r.put("result", "SUCCESS");
            records.add(r);
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("userPseudonym", userHash.length() >= 16 ? userHash.substring(0, 16) : userHash);
        payload.put("dateRange", startDate + " a " + endDate);
        payload.put("generatedAt", LocalDateTime.now().toString());
        payload.put("schemaVersion", "1.0.0");
        payload.put("totalRecords", records.size());
        payload.put("truncated", truncated);
        payload.put("totalMatchingRecords", totalMatching);
        payload.put("exportedRecords", records.size());
        payload.put("records", records);

        OAuthAuditLog exportAudit = new OAuthAuditLog();
        exportAudit.setEventType("LINKED_APPS_LOG_EXPORTED");
        exportAudit.setClientId("system");
        exportAudit.setUserIdHash(userHash);
        exportAudit.setDetails("Exportación forense de log de aplicaciones vinculadas generada");
        auditLogRepository.save(exportAudit);

        String canonicalJson;
        try {
            canonicalJson = objectMapper.writeValueAsString(payload);
        } catch (Exception e) {
            throw new RuntimeException("Error serializando export", e);
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
}
