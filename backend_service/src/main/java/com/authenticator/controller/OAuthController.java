package com.authenticator.controller;

import com.authenticator.domain.User;
import com.authenticator.dto.*;
import com.authenticator.exception.*;
import com.authenticator.repository.UserRepository;
import com.authenticator.service.OAuthService;
import com.authenticator.util.IpResolver;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/oauth")
public class OAuthController {

    private final OAuthService oAuthService;
    private final UserRepository userRepository;
    private final IpResolver ipResolver;
    private final com.authenticator.service.ReauthService reauthService;

    public OAuthController(OAuthService oAuthService,
                           UserRepository userRepository,
                           IpResolver ipResolver,
                           com.authenticator.service.ReauthService reauthService) {
        this.oAuthService = oAuthService;
        this.userRepository = userRepository;
        this.ipResolver = ipResolver;
        this.reauthService = reauthService;
    }

    /**
     * CU-0027 Anti-phishing: Consulta previa de cliente y redirect_uri autorizada.
     * Devuelve el nombre real de la plataforma para mostrar en el consentimiento.
     */
    @GetMapping(value = "/client-info", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> getClientInfo(@RequestParam("client_id") String clientId,
                                           @RequestParam("redirect_uri") String redirectUri) {
        try {
            ClientInfoResponse response = oAuthService.getClientInfo(clientId, redirectUri);
            return ResponseEntity.ok(response);
        } catch (OAuthException ex) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", ex.getError(),
                "error_description", ex.getMessage()
            ));
        }
    }

    /**
     * Paso 2: Intercambio de Access Token interno de SIP por Authorization Code de un solo uso.
     * Requiere autenticación con el JWT interno de SIP.
     */
    @PostMapping(value = "/token-exchange", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> tokenExchange(Authentication authentication,
                                           @Valid @RequestBody TokenExchangeRequest request,
                                           HttpServletRequest httpRequest) {
        if (authentication == null || authentication.getName() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "unauthorized", "error_description", "Autenticación requerida"));
        }

        UUID userId;
        try {
            userId = UUID.fromString(authentication.getName());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "invalid_token", "error_description", "Identificador de usuario inválido"));
        }

        User user = userRepository.findById(userId).orElse(null);
        if (user == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "user_not_found", "error_description", "Usuario no encontrado"));
        }

        String clientIp = ipResolver.resolveClientIp(httpRequest);
        try {
            TokenExchangeResponse response = oAuthService.processTokenExchange(user, request, clientIp);
            return ResponseEntity.ok(response);
        } catch (OAuthRiskNotAuthorizedException ex) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of(
                "error", ex.getError(),
                "error_description", ex.getMessage()
            ));
        } catch (OAuthException ex) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", ex.getError(),
                "error_description", ex.getMessage()
            ));
        }
    }

    /**
     * Paso 5: Intercambio de Authorization Code + PKCE por Access Token RS256 para el tercero.
     * Servidor a servidor. Exige client_secret_basic.
     */
    @PostMapping(value = "/token", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> issueToken(@RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader,
                                        @RequestParam(value = "grant_type", required = false) String grantTypeParam,
                                        @RequestParam(value = "code", required = false) String codeParam,
                                        @RequestParam(value = "redirect_uri", required = false) String redirectUriParam,
                                        @RequestParam(value = "code_verifier", required = false) String codeVerifierParam,
                                        @RequestParam(value = "client_id", required = false) String clientIdParam,
                                        @RequestParam(value = "client_secret", required = false) String clientSecretParam,
                                        @RequestBody(required = false) OAuthTokenRequest jsonBody,
                                        HttpServletRequest httpRequest) {
        OAuthTokenRequest tokenRequest = new OAuthTokenRequest();
        if (jsonBody != null) {
            tokenRequest.setGrantType(jsonBody.getGrantType());
            tokenRequest.setCode(jsonBody.getCode());
            tokenRequest.setRedirectUri(jsonBody.getRedirectUri());
            tokenRequest.setCodeVerifier(jsonBody.getCodeVerifier());
            tokenRequest.setClientId(jsonBody.getClientId());
            tokenRequest.setClientSecret(jsonBody.getClientSecret());
        }

        // Parámetros de formulario / query tienen precedencia
        if (grantTypeParam != null) tokenRequest.setGrantType(grantTypeParam);
        if (codeParam != null) tokenRequest.setCode(codeParam);
        if (redirectUriParam != null) tokenRequest.setRedirectUri(redirectUriParam);
        if (codeVerifierParam != null) tokenRequest.setCodeVerifier(codeVerifierParam);
        if (clientIdParam != null) tokenRequest.setClientId(clientIdParam);
        if (clientSecretParam != null) tokenRequest.setClientSecret(clientSecretParam);

        String clientIp = ipResolver.resolveClientIp(httpRequest);

        try {
            OAuthTokenResponse response = oAuthService.exchangeToken(
                authHeader,
                tokenRequest.getClientId(),
                tokenRequest.getClientSecret(),
                tokenRequest,
                clientIp
            );
            return ResponseEntity.ok(response);
        } catch (OAuthAuthenticationException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .header(HttpHeaders.WWW_AUTHENTICATE, "Basic realm=\"SIP OAuth\"")
                    .body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        } catch (OAuthClientLockedException ex) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .header(HttpHeaders.RETRY_AFTER, String.valueOf(ex.getRetryAfterSeconds()))
                    .body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        } catch (OAuthInvalidGrantException ex) {
            return ResponseEntity.badRequest().body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        } catch (OAuthException ex) {
            return ResponseEntity.badRequest().body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        }
    }

    /**
     * RFC 7662: Endpoint de Introspección de Tokens OAuth 2.0.
     * Exige autenticación del cliente OAuth (client_secret_basic o params).
     * Solo responde active: true para tokens emitidos para ese cliente (aud == client_id).
     */
    @PostMapping(value = "/introspect", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> introspectToken(@RequestHeader(value = HttpHeaders.AUTHORIZATION, required = false) String authHeader,
                                             @RequestParam(value = "client_id", required = false) String clientIdParam,
                                             @RequestParam(value = "client_secret", required = false) String clientSecretParam,
                                             @RequestParam(value = "token", required = false) String tokenParam,
                                             HttpServletRequest httpRequest) {
        String token = tokenParam;
        if (token == null || token.isBlank()) {
            token = httpRequest.getParameter("token");
        }

        String clientIp = ipResolver.resolveClientIp(httpRequest);
        try {
            Map<String, Object> introspectionResult = oAuthService.introspectToken(
                authHeader, clientIdParam, clientSecretParam, token, clientIp
            );
            return ResponseEntity.ok(introspectionResult);
        } catch (OAuthAuthenticationException ex) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .header(HttpHeaders.WWW_AUTHENTICATE, "Basic realm=\"SIP OAuth\"")
                    .body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        } catch (OAuthClientLockedException ex) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .header(HttpHeaders.RETRY_AFTER, String.valueOf(ex.getRetryAfterSeconds()))
                    .body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        } catch (OAuthException ex) {
            return ResponseEntity.status(HttpStatus.TOO_MANY_REQUESTS)
                    .body(Map.of("error", ex.getError(), "error_description", ex.getMessage()));
        }
    }

    /**
     * Callback local de sandbox offline (CU-0027).
     * Permite probar el ciclo completo de OAuth sin conexión a internet ni dependencia de dominios externos.
     */
    @GetMapping(value = "/sandbox/callback", produces = MediaType.TEXT_HTML_VALUE)
    public ResponseEntity<String> sandboxCallback(@RequestParam(value = "code", required = false) String code,
                                                  @RequestParam(value = "state", required = false) String state,
                                                  @RequestParam(value = "error", required = false) String error,
                                                  @RequestParam(value = "error_description", required = false) String errorDescription) {
        StringBuilder html = new StringBuilder();
        html.append("<!DOCTYPE html><html><head><meta charset=\"utf-8\">")
            .append("<title>OAuth Sandbox Callback</title>")
            .append("<style>")
            .append("body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #0f172a; color: #f8fafc; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; }")
            .append(".card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 32px; max-width: 520px; text-align: center; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }")
            .append("h2 { color: #38bdf8; margin-top: 0; }")
            .append(".box { background: #0f172a; border: 1px dashed #38bdf8; color: #4ade80; padding: 12px; border-radius: 8px; font-family: monospace; font-size: 13px; word-break: break-all; margin: 16px 0; }")
            .append(".err { color: #f87171; border-color: #f87171; }")
            .append("</style></head><body><div class=\"card\">");

        if (error != null) {
            html.append("<h2 style=\"color:#f87171;\">Autorización Rechazada</h2>")
                .append("<p>La plataforma simulada recibió un error de autorización:</p>")
                .append("<div class=\"box err\">Error: ").append(error)
                .append(errorDescription != null ? "<br>Detalle: " + errorDescription : "")
                .append("</div>");
        } else {
            html.append("<h2>Plataforma Simulada (Offline Sandbox)</h2>")
                .append("<p>Retorno de autorización recibido exitosamente en entorno local:</p>")
                .append("<div class=\"box\"><strong>Authorization Code:</strong><br>").append(code != null ? code : "N/A").append("</div>")
                .append("<p style=\"color:#94a3b8; font-size:12px;\">State: ").append(state != null ? state : "N/A").append("</p>")
                .append("<p style=\"color:#4ade80; font-size:13px;\">✓ Listo para canje servidor a servidor mediante POST /oauth/token</p>");
        }

        html.append("</div></body></html>");
        return ResponseEntity.ok(html.toString());
    }

    /**
     * Consulta de plataformas OAuth vinculadas por el usuario (Punto 5).
     * Autenticado con JWT de SIP. Retorna estado de token, último uso y alcances.
     */
    @GetMapping(value = "/linked-applications", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> getLinkedApplications(Authentication authentication) {
        if (authentication == null || authentication.getName() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "unauthorized", "error_description", "Autenticación requerida"));
        }
        UUID userId;
        try {
            userId = UUID.fromString(authentication.getName());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "invalid_token", "error_description", "Usuario inválido"));
        }

        return ResponseEntity.ok(oAuthService.getLinkedApplications(userId));
    }

    /**
     * Desvinculación de una plataforma OAuth por el usuario (Punto 5).
     * Revoca los tokens emitidos (y JTI en RevocationStore) y registra evento en oauth_audit_logs.
     */
    @PostMapping(value = "/unlink", consumes = MediaType.APPLICATION_JSON_VALUE, produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> unlinkApplication(Authentication authentication,
                                               @Valid @RequestBody UnlinkAppRequest request) {
        if (authentication == null || authentication.getName() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "unauthorized", "error_description", "Autenticación requerida"));
        }
        UUID userId;
        try {
            userId = UUID.fromString(authentication.getName());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "invalid_token", "error_description", "Usuario inválido"));
        }

        try {
            oAuthService.unlinkApplication(userId, request.getClientId());
            return ResponseEntity.ok(Map.of(
                "unlinked", true,
                "message", "Aplicación desvinculada exitosamente",
                "clientId", request.getClientId()
            ));
        } catch (OAuthException e) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", e.getError(),
                "error_description", e.getMessage()
            ));
        }
    }

    /**
     * Descarga certificada del log de aplicaciones vinculadas para auditoría externa (Punto 5).
     * Incluye metadatos, seudónimo, hash SHA-256 y firma digital RSA dedicada.
     * Exige reautenticación previa mediante cabecera X-Reauth-Token y rango de fechas acotado.
     */
    @GetMapping(value = "/linked-applications/export", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<?> exportLinkedApplicationsLog(
            Authentication authentication,
            @RequestHeader(value = "X-Reauth-Token", required = false) String reauthToken,
            @RequestParam(value = "startDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate startDate,
            @RequestParam(value = "endDate", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate endDate) {
        if (authentication == null || authentication.getName() == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "unauthorized", "error_description", "Autenticación requerida"));
        }
        UUID userId;
        try {
            userId = UUID.fromString(authentication.getName());
        } catch (IllegalArgumentException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
                    .body(Map.of("error", "invalid_token", "error_description", "Usuario inválido"));
        }

        if (reauthToken == null || reauthToken.isBlank() || !reauthService.validateAndConsumeReauthToken(userId, reauthToken, "EXPORT")) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "forbidden", "error_description", "Re-authentication required or invalid/expired token"));
        }

        try {
            Map<String, Object> export = oAuthService.exportLinkedApplicationsLog(userId, startDate, endDate);
            return ResponseEntity.ok(export);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                "error", "invalid_request",
                "error_description", e.getMessage()
            ));
        }
    }
}
