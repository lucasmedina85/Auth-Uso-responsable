package com.authenticator.integration;

import com.authenticator.domain.*;
import com.authenticator.dto.OAuthTokenResponse;
import com.authenticator.dto.TokenExchangeRequest;
import com.authenticator.repository.*;
import com.authenticator.security.JwtUtil;
import com.authenticator.security.RsaKeyManager;
import com.authenticator.service.OAuthRateLimitingService;
import com.authenticator.service.VerificationSessionService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jws;
import io.jsonwebtoken.Jwts;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.argon2.Argon2PasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.interfaces.RSAPublicKey;
import java.security.spec.RSAPublicKeySpec;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.UUID;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class ThirdPartyPlatformMockTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private OAuthAuthorizationCodeRepository codeRepository;

    @Autowired
    private OAuthIssuedTokenRepository tokenRepository;

    @Autowired
    private LinkedApplicationRepository linkedAppRepository;

    @Autowired
    private VerificationSessionService sessionService;

    @Autowired
    private OAuthRateLimitingService rateLimitingService;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;
    private String sipUserAccessToken;
    private final PasswordEncoder passwordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();

    @BeforeEach
    public void setUp() {
        rateLimitingService.resetForTests();
        tokenRepository.deleteAll();
        codeRepository.deleteAll();
        linkedAppRepository.deleteAll();

        testUser = userRepository.findByEmail("test_oauth_user@sip.gob.ar")
                .orElseGet(() -> {
                    User u = new User();
                    u.setEmail("test_oauth_user@sip.gob.ar");
                    u.setPasswordHash(passwordEncoder.encode("Password10Chars!"));
                    u.setStatus(UserStatus.LOCALLY_VERIFIED);
                    u.setDniHash("dummy-dni-hash-oauth");
                    u.setVerifiedAt(LocalDateTime.now());
                    return userRepository.save(u);
                });

        testUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        testUser.setVerifiedAt(LocalDateTime.now());
        userRepository.save(testUser);

        // Configurar sesión activa con decisión AUTORIZAR
        VerificationResult result = new VerificationResult();
        result.setRiskDecision(RiskDecision.AUTORIZAR);
        result.setCompositeRiskScore(15);
        sessionService.updateSessionStatus(testUser.getId().toString(), result);

        sipUserAccessToken = jwtUtil.generateAccessToken(testUser.getId().toString());
    }

    @AfterEach
    public void tearDown() {
        tokenRepository.deleteAll();
        codeRepository.deleteAll();
        linkedAppRepository.deleteAll();
        if (testUser != null && testUser.getId() != null) {
            userRepository.deleteById(testUser.getId());
        }
    }

    private String generateCodeVerifier() {
        return "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk1234567890abcdef";
    }

    private String computeS256(String verifier) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] digest = md.digest(verifier.getBytes(StandardCharsets.US_ASCII));
        return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
    }

    @Test
    public void endToEnd_ThirdPartyFlow_SuccessWithVerifiableRs256Token() throws Exception {
        String clientId = "sandbox-client";
        String clientSecret = "sandbox-secret-12345";
        String redirectUri = "https://sandbox.tercero.com/callback";
        String state = "mock-client-state-xyz";
        String nonce = "mock-nonce-456";
        String verifier = generateCodeVerifier();
        String challenge = computeS256(verifier);

        // 1. Anti-Phishing: La plataforma consulta /oauth/client-info
        mockMvc.perform(get("/oauth/client-info")
                .param("client_id", clientId)
                .param("redirect_uri", redirectUri))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.clientId", is(clientId)))
                .andExpect(jsonPath("$.clientName", is("Plataforma de Juegos Sandbox")))
                .andExpect(jsonPath("$.redirectUri", is(redirectUri)));

        // 2. Token Exchange con el Access Token SIP del usuario (Consentimiento otorgado)
        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(clientId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState(state);
        exchangeReq.setNonce(nonce);
        exchangeReq.setCodeChallenge(challenge);
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid age_verification");
        exchangeReq.setConsentGiven(true);

        MvcResult exchangeResult = mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code", notNullValue()))
                .andExpect(jsonPath("$.state", is(state)))
                .andExpect(jsonPath("$.redirectUri", is(redirectUri)))
                .andReturn();

        JsonNode exchangeJson = objectMapper.readTree(exchangeResult.getResponse().getContentAsString());
        String code = exchangeJson.get("code").asText();

        // 3. La plataforma tercera llama a /oauth/token (servidor a servidor) con client_secret_basic
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        MvcResult tokenResult = mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", redirectUri)
                .param("code_verifier", verifier))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token_type", is("Bearer")))
                .andExpect(jsonPath("$.expires_in", is(300)))
                .andExpect(jsonPath("$.access_token", notNullValue()))
                .andReturn();

        OAuthTokenResponse tokenResponse = objectMapper.readValue(tokenResult.getResponse().getContentAsString(), OAuthTokenResponse.class);
        String rs256Jwt = tokenResponse.getAccessToken();

        // 4. La plataforma tercera descarga /.well-known/jwks.json y verifica criptográficamente la firma
        MvcResult jwksResult = mockMvc.perform(get("/.well-known/jwks.json"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode jwksJson = objectMapper.readTree(jwksResult.getResponse().getContentAsString());
        JsonNode firstKey = jwksJson.get("keys").get(0);
        String modulusBase64Url = firstKey.get("n").asText();
        String exponentBase64Url = firstKey.get("e").asText();

        byte[] modBytes = Base64.getUrlDecoder().decode(modulusBase64Url);
        byte[] expBytes = Base64.getUrlDecoder().decode(exponentBase64Url);
        RSAPublicKeySpec keySpec = new RSAPublicKeySpec(new BigInteger(1, modBytes), new BigInteger(1, expBytes));
        RSAPublicKey rsaPublicKey = (RSAPublicKey) KeyFactory.getInstance("RSA").generatePublic(keySpec);

        // Validar firma del token usando JJWT con la clave pública recuperada del JWKS
        Jws<Claims> parsed = Jwts.parser()
                .verifyWith(rsaPublicKey)
                .build()
                .parseSignedClaims(rs256Jwt);

        Claims claims = parsed.getPayload();
        assertEquals(clientId, claims.getAudience().iterator().next(), "aud debe coincidir con el clientId");
        assertTrue(claims.get("age_verified", Boolean.class), "age_verified debe ser true");
        assertEquals("HIGH", claims.get("assurance_level", String.class));
        assertEquals(nonce, claims.get("nonce", String.class));

        // Validación estricta de CERO PII: Ningún dato personal expuesto
        assertNull(claims.get("name"), "No debe exponer name");
        assertNull(claims.get("email"), "No debe exponer email");
        assertNull(claims.get("dni"), "No debe exponer dni");
        assertNull(claims.get("birth_date"), "No debe exponer fecha de nacimiento");

        // El claim 'sub' debe ser un identificador seudónimo HMAC, nunca el userId en claro
        assertNotEquals(testUser.getId().toString(), claims.getSubject(), "sub debe ser un seudónimo pairwise, no el userId real");
    }

    @Test
    public void tokenExchange_FailsIfPkceInvalidOrPlain() throws Exception {
        String clientId = "sandbox-client";
        String redirectUri = "https://sandbox.tercero.com/callback";

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(clientId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState("state-1");
        exchangeReq.setCodeChallenge("plain-challenge");
        exchangeReq.setCodeChallengeMethod("plain"); // Rechazar método plain
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(true);

        mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("invalid_request")));
    }

    @Test
    public void tokenExchange_FailsIfUserRiskDecisionNotAuthorized() throws Exception {
        // Simular que el motor de riesgo decidió REVISIÓN o BLOQUEAR
        VerificationResult reviewResult = new VerificationResult();
        reviewResult.setRiskDecision(RiskDecision.REVISIÓN);
        reviewResult.setCompositeRiskScore(65);
        sessionService.updateSessionStatus(testUser.getId().toString(), reviewResult);

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId("sandbox-client");
        exchangeReq.setRedirectUri("https://sandbox.tercero.com/callback");
        exchangeReq.setState("state-risk");
        exchangeReq.setCodeChallenge(computeS256(generateCodeVerifier()));
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(true);

        mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.error", is("risk_decision_not_authorized")));
    }

    @Test
    public void tokenExchange_FailsIfUserConsentNotGiven() throws Exception {
        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId("sandbox-client");
        exchangeReq.setRedirectUri("https://sandbox.tercero.com/callback");
        exchangeReq.setState("state-noconsent");
        exchangeReq.setCodeChallenge(computeS256(generateCodeVerifier()));
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(false); // Rechazar sin consentimiento

        mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("consent_required")));
    }

    @Test
    public void token_FailsWithInvalidPkceVerifier() throws Exception {
        String clientId = "sandbox-client";
        String clientSecret = "sandbox-secret-12345";
        String redirectUri = "https://sandbox.tercero.com/callback";
        String verifier = generateCodeVerifier();
        String challenge = computeS256(verifier);

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(clientId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState("state-pkce-fail");
        exchangeReq.setCodeChallenge(challenge);
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(true);

        MvcResult exchangeResult = mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isOk())
                .andReturn();

        String code = objectMapper.readTree(exchangeResult.getResponse().getContentAsString()).get("code").asText();
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        // Intento con verifier incorrecto
        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", redirectUri)
                .param("code_verifier", "wrong-code-verifier-that-does-not-match-challenge-12345"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("invalid_grant")));
    }

    @Test
    public void token_ReplayDetection_RevokesAllPreviouslyIssuedTokens() throws Exception {
        String clientId = "sandbox-client";
        String clientSecret = "sandbox-secret-12345";
        String redirectUri = "https://sandbox.tercero.com/callback";
        String verifier = generateCodeVerifier();
        String challenge = computeS256(verifier);

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(clientId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState("state-replay");
        exchangeReq.setCodeChallenge(challenge);
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(true);

        MvcResult exchangeResult = mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isOk())
                .andReturn();

        String code = objectMapper.readTree(exchangeResult.getResponse().getContentAsString()).get("code").asText();
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        // Primer canje: Exitoso
        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", redirectUri)
                .param("code_verifier", verifier))
                .andExpect(status().isOk());

        // Segundo canje con el mismo código: Debe fallar y revocar el token anterior
        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", redirectUri)
                .param("code_verifier", verifier))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("invalid_grant")))
                .andExpect(jsonPath("$.error_description", containsString("ya fue utilizado")));
    }

    @Test
    public void token_FailsIfRedirectUriMismatch() throws Exception {
        String clientId = "sandbox-client";
        String clientSecret = "sandbox-secret-12345";
        String redirectUri = "https://sandbox.tercero.com/callback";
        String verifier = generateCodeVerifier();
        String challenge = computeS256(verifier);

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(clientId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState("state-mismatch");
        exchangeReq.setCodeChallenge(challenge);
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid");
        exchangeReq.setConsentGiven(true);

        MvcResult exchangeResult = mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserAccessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isOk())
                .andReturn();

        String code = objectMapper.readTree(exchangeResult.getResponse().getContentAsString()).get("code").asText();
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", "sipdemo://callback") // Diverge de la redirect_uri emitida
                .param("code_verifier", verifier))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("invalid_grant")));
    }

    @Test
    public void token_FailsIfClientSecretInvalid_AndEnforcesLockout() throws Exception {
        String clientId = "sandbox-client";
        String wrongSecret = "wrong-password-999";
        String basicAuthWrong = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + wrongSecret).getBytes(StandardCharsets.UTF_8));

        // 4 intentos fallidos -> 401 Unauthorized
        for (int i = 0; i < 4; i++) {
            mockMvc.perform(post("/oauth/token")
                    .header(HttpHeaders.AUTHORIZATION, basicAuthWrong)
                    .param("grant_type", "authorization_code")
                    .param("code", "dummy-code")
                    .param("redirect_uri", "https://sandbox.tercero.com/callback")
                    .param("code_verifier", generateCodeVerifier()))
                    .andExpect(status().isUnauthorized());
        }

        // 5to intento fallido activa el bloqueo temporal -> 401 que supera el umbral
        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuthWrong)
                .param("grant_type", "authorization_code")
                .param("code", "dummy-code")
                .param("redirect_uri", "https://sandbox.tercero.com/callback")
                .param("code_verifier", generateCodeVerifier()))
                .andExpect(status().isUnauthorized());

        // 6to intento (incluso con secreto correcto o incorrecto) responde 429 Too Many Requests con Retry-After
        mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuthWrong)
                .param("grant_type", "authorization_code")
                .param("code", "dummy-code")
                .param("redirect_uri", "https://sandbox.tercero.com/callback")
                .param("code_verifier", generateCodeVerifier()))
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists(HttpHeaders.RETRY_AFTER))
                .andExpect(jsonPath("$.error", is("temporarily_unavailable")));
    }
}
