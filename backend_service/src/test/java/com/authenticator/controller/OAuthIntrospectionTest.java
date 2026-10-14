package com.authenticator.controller;

import com.authenticator.domain.OAuthClient;
import com.authenticator.domain.User;
import com.authenticator.domain.UserStatus;
import com.authenticator.dto.TokenExchangeRequest;
import com.authenticator.repository.OAuthAuthorizationCodeRepository;
import com.authenticator.repository.OAuthClientRepository;
import com.authenticator.repository.OAuthIssuedTokenRepository;
import com.authenticator.repository.UserRepository;
import com.authenticator.security.JwtUtil;
import com.authenticator.security.RevocationStore;
import com.authenticator.service.OAuthRateLimitingService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Base64;
import java.util.UUID;

import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class OAuthIntrospectionTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private OAuthAuthorizationCodeRepository codeRepository;

    @Autowired
    private OAuthIssuedTokenRepository tokenRepository;

    @Autowired
    private OAuthClientRepository clientRepository;

    @Autowired
    private RevocationStore revocationStore;

    @Autowired
    private OAuthRateLimitingService rateLimitingService;

    @Autowired
    private JwtUtil jwtUtil;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;
    private String sipUserToken;
    private final PasswordEncoder passwordEncoder = Argon2PasswordEncoder.defaultsForSpringSecurity_v5_8();

    private final String clientId = "sandbox-client";
    private final String clientSecret = "sandbox-secret-12345";
    private final String clientOtherId = "other-client";
    private final String clientOtherSecret = "other-secret-12345";

    @BeforeEach
    public void setUp() {
        rateLimitingService.resetForTests();
        tokenRepository.deleteAll();
        codeRepository.deleteAll();

        if (!clientRepository.existsById(clientId)) {
            OAuthClient sandbox = new OAuthClient();
            sandbox.setClientId(clientId);
            sandbox.setClientSecretHash(new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder().encode(clientSecret));
            sandbox.setName("Plataforma de Juegos Sandbox");
            sandbox.setAllowedScopes("openid,age_verification");
            sandbox.setStatus("ACTIVE");
            sandbox.setRedirectUris(new java.util.HashSet<>(java.util.List.of(
                    "https://sandbox.tercero.com/callback",
                    "sipdemo://callback",
                    "http://127.0.0.1:8080/oauth/sandbox/callback",
                    "http://localhost:8080/oauth/sandbox/callback"
            )));
            clientRepository.save(sandbox);
        }

        if (!clientRepository.existsById(clientOtherId)) {
            OAuthClient other = new OAuthClient();
            other.setClientId(clientOtherId);
            other.setClientSecretHash(new org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder().encode(clientOtherSecret));
            other.setName("Otra Plataforma Externa");
            other.setAllowedScopes("openid");
            other.setStatus("ACTIVE");
            other.setRedirectUris(new java.util.HashSet<>(java.util.List.of(
                    "https://other.com/cb"
            )));
            clientRepository.save(other);
        }

        testUser = userRepository.findByEmail("introspect_user@sip.gob.ar")
                .orElseGet(() -> {
                    User u = new User();
                    u.setEmail("introspect_user@sip.gob.ar");
                    u.setPasswordHash(passwordEncoder.encode("Password10Chars!"));
                    u.setStatus(UserStatus.LOCALLY_VERIFIED);
                    u.setDniHash("dummy-introspect-dni");
                    u.setVerifiedAt(LocalDateTime.now());
                    return userRepository.save(u);
                });

        testUser.setStatus(UserStatus.LOCALLY_VERIFIED);
        testUser.setVerifiedAt(LocalDateTime.now());
        userRepository.save(testUser);

        sipUserToken = jwtUtil.generateAccessToken(testUser.getId().toString(), "USER");
    }

    private String issueOAuthToken(String cId, String cSecret, String redirectUri) throws Exception {
        String verifier = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~";
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] digest = md.digest(verifier.getBytes(StandardCharsets.US_ASCII));
        String challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(digest);

        TokenExchangeRequest exchangeReq = new TokenExchangeRequest();
        exchangeReq.setClientId(cId);
        exchangeReq.setRedirectUri(redirectUri);
        exchangeReq.setState("xyz123");
        exchangeReq.setNonce("nonce456");
        exchangeReq.setCodeChallenge(challenge);
        exchangeReq.setCodeChallengeMethod("S256");
        exchangeReq.setScope("openid age_verification");
        exchangeReq.setConsentGiven(true);

        MvcResult exchangeResult = mockMvc.perform(post("/oauth/token-exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer " + sipUserToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(exchangeReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode exchangeJson = objectMapper.readTree(exchangeResult.getResponse().getContentAsString());
        String code = exchangeJson.get("code").asText();

        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((cId + ":" + cSecret).getBytes(StandardCharsets.UTF_8));

        MvcResult tokenResult = mockMvc.perform(post("/oauth/token")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .param("grant_type", "authorization_code")
                .param("code", code)
                .param("redirect_uri", redirectUri)
                .param("code_verifier", verifier))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode tokenJson = objectMapper.readTree(tokenResult.getResponse().getContentAsString());
        return tokenJson.get("access_token").asText();
    }

    @Test
    public void introspectToken_WithoutClientAuth_Returns401WithWwwAuthenticate() throws Exception {
        mockMvc.perform(post("/oauth/introspect")
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", "dummy.token"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, "Basic realm=\"SIP OAuth\""));
    }

    @Test
    public void introspectToken_WithWrongClientSecret_Returns401() throws Exception {
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":wrong-secret").getBytes(StandardCharsets.UTF_8));

        mockMvc.perform(post("/oauth/introspect")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", "dummy.token"))
                .andExpect(status().isUnauthorized())
                .andExpect(header().string(HttpHeaders.WWW_AUTHENTICATE, "Basic realm=\"SIP OAuth\""));
    }

    @Test
    public void introspectToken_WithInvalidOrMalformedToken_ReturnsActiveFalse() throws Exception {
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        mockMvc.perform(post("/oauth/introspect")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", "invalid.jwt.token"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)));
    }

    @Test
    public void introspectToken_WithValidToken_ReturnsActiveTrueAndClaims() throws Exception {
        String rs256Token = issueOAuthToken(clientId, clientSecret, "https://sandbox.tercero.com/callback");
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        mockMvc.perform(post("/oauth/introspect")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", rs256Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(true)))
                .andExpect(jsonPath("$.sub").isString())
                .andExpect(jsonPath("$.client_id", is(clientId)))
                .andExpect(jsonPath("$.scope", is("openid age_verification")))
                .andExpect(jsonPath("$.age_verified", is(true)))
                .andExpect(jsonPath("$.exp").isNumber());
    }

    @Test
    public void introspectToken_WhenTokenBelongsToDifferentClient_ReturnsActiveFalseWithoutMetadata() throws Exception {
        // Token emitido para sandbox-client
        String rs256Token = issueOAuthToken(clientId, clientSecret, "https://sandbox.tercero.com/callback");

        // Autenticación como other-client (aud != other-client)
        String basicAuthOther = "Basic " + Base64.getEncoder().encodeToString((clientOtherId + ":" + clientOtherSecret).getBytes(StandardCharsets.UTF_8));

        mockMvc.perform(post("/oauth/introspect")
                .header(HttpHeaders.AUTHORIZATION, basicAuthOther)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", rs256Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)))
                .andExpect(jsonPath("$.sub").doesNotExist())
                .andExpect(jsonPath("$.scope").doesNotExist());
    }

    @Test
    public void introspectToken_WhenTokenRevokedInStore_ReturnsActiveFalse() throws Exception {
        String rs256Token = issueOAuthToken(clientId, clientSecret, "https://sandbox.tercero.com/callback");
        String basicAuth = "Basic " + Base64.getEncoder().encodeToString((clientId + ":" + clientSecret).getBytes(StandardCharsets.UTF_8));

        // Extraer jti del token y revocarlo activamente en el RevocationStore
        var issuedTokens = tokenRepository.findAll();
        assertFalse(issuedTokens.isEmpty());
        String jti = issuedTokens.get(issuedTokens.size() - 1).getJti();
        assertNotNull(jti);

        revocationStore.revoke(jti, Duration.ofMinutes(15));

        mockMvc.perform(post("/oauth/introspect")
                .header(HttpHeaders.AUTHORIZATION, basicAuth)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .param("token", rs256Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.active", is(false)));
    }
}
